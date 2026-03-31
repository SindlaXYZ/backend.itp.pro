<?php

namespace App\Command;

use App\Attributes\CronSchedule;
use App\Command\Middleware\CommandMiddleware;
use App\Utils\CronExpression;
use App\Utils\Utils;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\BufferedOutput;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\DependencyInjection\ParameterBag\ParameterBagInterface;
use Symfony\Component\Uid\Uuid;

#[AsCommand(
    name       : 'app:cron',
    description: 'Cron command'
)]
final class CronCommand extends CommandMiddleware
{
    protected BufferedOutput $bufferedOutput;
    protected string         $scheduleStateFile;

    public function __construct(
        private readonly ParameterBagInterface $parameterBag
    )
    {
        parent::__construct();
        $this->bufferedOutput    = new BufferedOutput();
        $this->scheduleStateFile = $this->parameterBag->get('kernel.project_dir') . '/var/cron-schedule.json';
    }

    protected function configure(): void
    {
        $this
            ->setHelp('This command allows you to test various development components and services.')
            // Mandatory
            ->addOption('action', null, InputOption::VALUE_REQUIRED)
            // Optional
            ->addOption('secondArgument', null, InputOption::VALUE_OPTIONAL)
            ->addOption('thirdArgument', null, InputOption::VALUE_OPTIONAL);
    }

    /**
     * This optional method is the first one executed for a command after configure() and is useful to initialize properties based on the input arguments and options.
     */
    protected function initialize(InputInterface $input, OutputInterface $output): void
    {
        parent::initialize($input, $output);
    }

    /**
     * This method is executed after initialize() and before execute(). Its purpose is to check if some options/arguments are missing and interactively ask the user for those values.
     *
     * This method is completely optional. If you are developing an internal console command, you probably should not implement this method because it requires quite a lot of work.
     * However, if the command is meant to be used by external users, this method is a nice way to fall back and prevent errors.
     */
    protected function interact(InputInterface $input, OutputInterface $output): void
    {
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        return $this->try($input, $output, $this);
    }

    /**
     * clear; /usr/bin/php /srv/${DKZ_DOMAIN}/bin/console app:cron --verbose --action=test
     */
    protected function test(): int
    {
        $reflection = new \ReflectionClass($this);
        $attributes = $reflection->getAttributes(AsCommand::class);
        $name       = $attributes[0]->getArguments()['name'] ?? 'Unknown Command Name';
        $this->io->success(sprintf("[%s] It works!", $name));

        return self::SUCCESS;
    }

    #################################################################################################################################################
    #################################################################################################################################################

    /**
     * clear; /usr/bin/php bin/console app:cron --verbose --action=every1And5Minutes
     */
    #[CronSchedule(expression: '* * * * *', timezone: 'Europe/Bucharest', window: 'PT1M', hcPing: 'https://hc-ping.com/change-this-another-one-uniq-id')]
    #[CronSchedule(expression: '*/5 * * * *', timezone: 'Europe/Bucharest', window: 'PT1M', hcPing: 'https://hc-ping.com/change-this-another-two-uniq-id')]
    protected function every1And5Minutes(): int
    {
        $this->io->comment(sprintf('Running %s() ... ', __FUNCTION__));

        // Simulate some work
        sleep(mt_rand(3, 15));

        $this->io->comment(sprintf('... %s() finished.', __FUNCTION__));

        return self::SUCCESS;
    }

    #################################################################################################################################################
    #################################################################################################################################################

    /**
     * This is the main method that should be called every minute from linux cron (!!) WITHOUT FLOCK (!!)
     *
     * Usage: * * * * root /usr/bin/php -d memory_limit=2G /srv/${DKZ_DOMAIN}/bin/console app:cron --verbose --action=common
     */
    protected function common(): int
    {
        $nowUtc = new \DateTimeImmutable('now', new \DateTimeZone('UTC'));
        $state  = $this->loadScheduleState();

        foreach ($this->getScheduledMethods() as $key => $item) {
            $methodName = $item['method'];
            $schedule   = $item['schedule'];

            try {
                if (!$this->shouldRun($schedule, $state[$key] ?? null, $nowUtc)) {
                    continue;
                }
            } catch (\Throwable $throwable) {
                $this->io->error(sprintf('Skipping %s(): %s', $methodName, $throwable->getMessage()));
                continue;
            }

            $this->io->comment(sprintf('Executing scheduled action %s() [%s]', $methodName, $schedule->expression));

            $hcRid = null;
            if (!empty($schedule->hcPing)) {
                try {
                    $hcRid = Uuid::v7()->toRfc4122();
                    Utils::healthChecksIOStart($schedule->hcPing, $hcRid);
                } catch (\Throwable $throwable) {
                    $this->io->warning(sprintf('%s() healthChecksIOStart failed: %s', $methodName, $throwable->getMessage()));
                }
            }

            try {
                $result = $this->{$methodName}();
            } catch (\Throwable $throwable) {
                $this->io->error(sprintf('%s() failed: %s', $methodName, $throwable->getMessage()));
                $result = null;
            } finally {
                if (!empty($schedule->hcPing) && $hcRid) {
                    try {
                        Utils::healthChecksIOFinish($schedule->hcPing, $hcRid);
                    } catch (\Throwable $throwable) {
                        $this->io->warning(sprintf('%s() healthChecksIOFinish failed: %s', $methodName, $throwable->getMessage()));
                    }
                }
            }

            if ($result === null) {
                $result = self::SUCCESS;
            }

            if ($result === self::SUCCESS) {
                $state[$key] = $nowUtc->format(\DATE_ATOM);
            } else {
                $this->io->warning(sprintf('%s() returned status %s, next run will retry.', $methodName, (string)$result));
            }
        }

        $this->persistScheduleState($state);

        return self::SUCCESS;
    }

    #################################################################################################################################################

    /**
     * @return array<string, array{method: string, schedule: CronSchedule}>
     */
    private function getScheduledMethods(): array
    {
        $reflection = new \ReflectionObject($this);
        $methods    = [];

        foreach ($reflection->getMethods(\ReflectionMethod::IS_PROTECTED) as $method) {
            foreach ($method->getAttributes(CronSchedule::class) as $attribute) {
                /** @var CronSchedule $schedule */
                $schedule = $attribute->newInstance();
                // Create unique key for each method-schedule combination using expression hash
                $key           = $method->getName() . '_' . md5($schedule->expression);
                $methods[$key] = [
                    'method'   => $method->getName(),
                    'schedule' => $schedule
                ];
            }
        }

        return $methods;
    }

    private function shouldRun(CronSchedule $schedule, ?string $lastRunIso, \DateTimeImmutable $nowUtc): bool
    {
        $timezone   = new \DateTimeZone($schedule->timezone);
        $nowInZone  = $nowUtc->setTimezone($timezone);
        $window     = new \DateInterval($schedule->window);
        $lastRun    = $lastRunIso ? new \DateTimeImmutable($lastRunIso) : null;
        $lastInZone = $lastRun ? $lastRun->setTimezone($timezone) : null;

        if (!CronExpression::isDue($schedule->expression, $nowInZone)) {
            return false;
        }

        if ($lastInZone && $nowInZone->sub($window) <= $lastInZone) {
            return false;
        }

        return true;
    }

    private function loadScheduleState(): array
    {
        if (!file_exists($this->scheduleStateFile)) {
            return [];
        }

        $contents = file_get_contents($this->scheduleStateFile);

        if (false === $contents) {
            return [];
        }

        $data = json_decode($contents, true);

        return is_array($data) ? $data : [];
    }

    private function persistScheduleState(array $state): void
    {
        $directory = dirname($this->scheduleStateFile);
        if (!is_dir($directory)) {
            mkdir($directory, 0777, true);
        }

        file_put_contents($this->scheduleStateFile, json_encode($state, \JSON_PRETTY_PRINT));
    }
}

<?php

namespace App\Command\Dev;

use App\Command\Middleware\CommandMiddleware;
use App\Utils\Utils;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Question\ConfirmationQuestion;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

#[AsCommand(
    name       : 'app:dev',
    description: 'DEV only command'
)]
final class DevCommand extends CommandMiddleware
{
    public function __construct(
        #[Autowire('%kernel.environment%')] private readonly string $projectEnv,
        #[Autowire('%kernel.project_dir%')] private readonly string $projectDir
    )
    {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this
            ->setHelp('This command allows you to test various development components and services.')
            // Mandatory
            ->addOption('action', null, InputOption::VALUE_REQUIRED)
            // Optional
            ->addOption('email', null, InputOption::VALUE_OPTIONAL)
            ->addOption('sqlLimit', null, InputOption::VALUE_OPTIONAL);
    }

    /**
     * This optional method is the first one executed for a command after configure() and is useful to initialize properties based on the input arguments and options.
     */
    protected function initialize(InputInterface $input, OutputInterface $output): void
    {
        parent::initialize($input, $output);
    }

    /**
     * This method is executed after initialize() and before execute(). Its purpose is to check if some of the options/arguments are missing and interactively ask the user for those values.
     *
     * This method is completely optional. If you are developing an internal console command, you probably should not implement this method because it requires quite a lot of work.
     * However, if the command is meant to be used by external users, this method is a nice way to fall back and prevent errors.
     */
    protected function interact(InputInterface $input, OutputInterface $output): void
    {
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        if (!in_array($this->projectEnv, ['dev', 'test'])) {
            $this->io->error(sprintf('This method is not allowed to run on the `%s` environment !', $_ENV['APP_ENV']));
            if (!($this->getHelper('question'))->ask($input, $output, new ConfirmationQuestion(
                'Continue with this action (y|yes)?',
                false,
                '/^(y|yes)/i'
            ))) {
                return self::FAILURE;
            }
        }

        return $this->try($input, $output, $this);
    }

    /**
     * clear; /usr/bin/php /srv/${DKZ_DOMAIN}/bin/console app:dev --verbose --action=test
     */
    protected function test(): int
    {
        $reflection = new \ReflectionClass($this);
        $attributes = $reflection->getAttributes(AsCommand::class);
        $name       = $attributes[0]->getArguments()['name'] ?? 'Unknown Command Name';
        $this->io->comment(sprintf("[%s] Project directory: %s", $name, $this->projectDir));
        $this->io->comment(sprintf("[%s] Project env: %s", $name, $this->projectEnv));
        $this->io->comment(sprintf("[%s] \$_ENV['APP_ENV']: %s", $name, $_ENV['APP_ENV']));
        $this->io->success(sprintf("[%s] It works!", $name));

        return self::SUCCESS;
    }

    /**
     * clear; /usr/bin/php /srv/${DKZ_DOMAIN}/bin/console app:dev --verbose --action=cliOrCron
     */
    protected function cliOrCron(): int
    {
        if ($this->hasTty()) {
            $this->io->success('CLI');
            // file_put_contents($this->projectDir . '/test-cli.log', date('H:i:s') . ' ' . microtime(false) . "\n", FILE_APPEND);
        } else {
            $this->io->success('CRON');
            // file_put_contents($this->projectDir . '/test-cron.log', date('H:i:s') . ' ' . microtime(false) . "\n", FILE_APPEND);
        }

        return self::SUCCESS;
    }

    /**
     * clear; APP_ENV=dev  /usr/bin/php /srv/${DKZ_DOMAIN}/bin/console app:dev --verbose --action=databaseReset
     */
    protected function databaseReset(): int
    {
        $this->databaseDrop();
        $this->databaseMigrate();
        return self::SUCCESS;
    }

    /**
     * clear; APP_ENV=dev  /usr/bin/php /srv/${DKZ_DOMAIN}/bin/console app:dev --verbose --action=auditDatabaseReset
     * APP_ENV=$DKZ_SYMFONY_ENV APP_DEBUG=0 /usr/bin/php bin/console audit:schema:update --force
     */
    protected function auditDatabaseReset(): int
    {
        $this->auditDropAndRecreateSchema();
        return self::SUCCESS;
    }

    /**
     * clear; APP_ENV=dev  /usr/bin/php /srv/${DKZ_DOMAIN}/bin/console app:dev --verbose --action=databaseFixMigration
     *
     * @throws \Exception
     */
    protected function databaseFixMigration(): int
    {
        new Utils()->databaseFixMigration();
        return self::SUCCESS;
    }
}

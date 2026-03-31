<?php

namespace App\Command;

use App\Command\Middleware\CommandMiddleware;
use App\Service\AppService;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

#[AsCommand(
    name       : 'app:simple-command',
    description: 'Simple command'
)]
final class SimpleCommand extends CommandMiddleware
{
    public function __construct(
        #[Autowire('%kernel.project_dir%')] private readonly string $projectDir,
        private readonly AppService                                 $appService
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
     * clear; /usr/bin/php /srv/${DKZ_DOMAIN}/bin/console app:simple-command --verbose --action=test
     */
    protected function test(): int
    {
        $reflection = new \ReflectionClass($this);
        $attributes = $reflection->getAttributes(AsCommand::class);
        $name       = $attributes[0]->getArguments()['name'] ?? 'Unknown Command Name';
        $this->appService->loggerInfo();
        $this->io->comment(sprintf("[%s] Project directory: %s", $name, $this->projectDir));
        $this->io->success(sprintf("[%s] It works!", $name));

        return self::SUCCESS;
    }
}

<?php

namespace App\EventSubscriber\Console;

use App\Utils\Utils;
use Symfony\Component\Console\ConsoleEvents;
use Symfony\Component\Console\Event\ConsoleTerminateEvent;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;

class DoctrineMigrationsDiffSubscriber implements EventSubscriberInterface
{
    public function __construct(
        private readonly Utils $utils
    ) {
    }

    public static function getSubscribedEvents(): array
    {
        return [
            ConsoleEvents::TERMINATE => 'onConsoleTerminate',
        ];
    }

    public function onConsoleTerminate(ConsoleTerminateEvent $event): void
    {
        $commandName = $event->getCommand()?->getName();

        if ('doctrine:migrations:diff' !== $commandName) {
            return;
        }

        // Only process if the command was successful (exit code 0)
        if (0 !== $event->getExitCode()) {
            return;
        }

        $event->getOutput()->writeln('<info>Applying database migration fixer...</info>');

        try {
            $this->utils->databaseFixMigration();
            $event->getOutput()->writeln('<info>Migration files have been fixed.</info>');
        } catch (\Exception $e) {
            $event->getOutput()->writeln(sprintf('<error>Error fixing migration: %s</error>', $e->getMessage()));
        }
    }
}

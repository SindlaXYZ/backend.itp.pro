<?php

namespace App\Service;

use Psr\Log\LoggerInterface;

readonly class AppService
{
    public function __construct(
        private LoggerInterface $logger
    )
    {
    }

    public function loggerInfo(): void
    {
        $this->logger->info('My custom logged info.');
    }
}

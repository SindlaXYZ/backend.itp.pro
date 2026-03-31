<?php

namespace App\ApiResource\Time;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProviderInterface;

final class TimeProvider implements ProviderInterface
{
    /**
     * @throws \DateMalformedStringException
     * @throws \DateInvalidTimeZoneException
     */
    public function provide(Operation $operation, array $uriVariables = [], array $context = []): TimeResource
    {
        $tz  = new \DateTimeZone($_ENV['APP_TIMEZONE'] ?? date_default_timezone_get());
        $now = new \DateTimeImmutable('now', $tz);

        return new TimeResource(
            now     : $now->format(DATE_ATOM),
            timezone: $now->getTimezone()->getName(),
            unix    : $now->getTimestamp(),
            now_utc : $now->setTimezone(new \DateTimeZone('UTC'))->format(DATE_ATOM),
        );
    }
}

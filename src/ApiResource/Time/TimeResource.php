<?php

namespace App\ApiResource\Time;

use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;

#[ApiResource(
    operations: [new Get(uriTemplate: '/time')],
    provider  : TimeProvider::class
)]
final readonly class TimeResource
{
    public function __construct(
        public string $now,
        public string $timezone,
        public int    $unix,
        public string $now_utc,
    )
    {
    }
}

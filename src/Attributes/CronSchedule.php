<?php

namespace App\Attributes;

use Attribute;

#[Attribute(Attribute::TARGET_METHOD | Attribute::IS_REPEATABLE)]
readonly class CronSchedule
{
    public function __construct(
        public string  $expression,
        public string  $timezone = 'UTC',
        public string  $window = 'PT15M',
        public ?string $hcPing = null
    )
    {
    }
}

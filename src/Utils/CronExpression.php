<?php

namespace App\Utils;

class CronExpression
{
    public static function isDue(string $expression, \DateTimeInterface $dateTime): bool
    {
        $parts = preg_split('/\s+/', trim($expression));

        if (!$parts || count($parts) !== 5) {
            throw new \InvalidArgumentException(sprintf('Invalid cron expression "%s"', $expression));
        }

        [$minute, $hour, $dayOfMonth, $month, $dayOfWeek] = $parts;

        $minuteMatch     = self::matchField($minute, (int)$dateTime->format('i'), 0, 59);
        $hourMatch       = self::matchField($hour, (int)$dateTime->format('G'), 0, 23);
        $monthMatch      = self::matchField($month, (int)$dateTime->format('n'), 1, 12);
        $dayOfMonthMatch = self::matchField($dayOfMonth, (int)$dateTime->format('j'), 1, 31);

        $weekDayCurrent = (int)$dateTime->format('w'); // 0 (for Sunday) through 6 (for Saturday)
        $dayOfWeekMatch = self::matchField($dayOfWeek, $weekDayCurrent, 0, 7)
            || ($weekDayCurrent === 0 && self::matchField($dayOfWeek, 7, 0, 7));

        $dayMatch = self::computeDayMatch($dayOfMonth, $dayOfWeek, $dayOfMonthMatch, $dayOfWeekMatch);

        return $minuteMatch && $hourMatch && $monthMatch && $dayMatch;
    }

    private static function matchField(string $field, int $value, int $min, int $max): bool
    {
        if (self::isWildcard($field)) {
            return true;
        }

        foreach (explode(',', $field) as $segment) {
            if (self::matchSegment(trim($segment), $value, $min, $max)) {
                return true;
            }
        }

        return false;
    }

    private static function matchSegment(string $segment, int $value, int $min, int $max): bool
    {
        if ($segment === '') {
            return false;
        }

        [$range, $step] = array_pad(explode('/', $segment, 2), 2, null);
        $step = $step !== null ? max(1, (int)$step) : 1;

        [$start, $end] = self::parseRange($range, $min, $max);

        for ($candidate = $start; $candidate <= $end; $candidate += $step) {
            if ($candidate === $value) {
                return true;
            }
        }

        return false;
    }

    private static function parseRange(string $range, int $min, int $max): array
    {
        if (self::isWildcard($range)) {
            return [$min, $max];
        }

        if (str_contains($range, '-')) {
            [$start, $end] = array_map('intval', explode('-', $range, 2));
        } else {
            $start = (int)$range;
            $end   = $start;
        }

        return [
            max($min, $start),
            min($max, $end),
        ];
    }

    private static function computeDayMatch(string $dayOfMonthField, string $dayOfWeekField, bool $dayOfMonthMatch, bool $dayOfWeekMatch): bool
    {
        $dayOfMonthWildcard = self::isWildcard($dayOfMonthField);
        $dayOfWeekWildcard  = self::isWildcard($dayOfWeekField);

        if ($dayOfMonthWildcard && $dayOfWeekWildcard) {
            return true;
        }

        if ($dayOfMonthWildcard) {
            return $dayOfWeekMatch;
        }

        if ($dayOfWeekWildcard) {
            return $dayOfMonthMatch;
        }

        return $dayOfMonthMatch || $dayOfWeekMatch;
    }

    private static function isWildcard(string $value): bool
    {
        return trim($value) === '*';
    }
}

<?php

namespace App\Utils;

use Random\RandomException;
use Symfony\Component\HttpClient\HttpClient;
use Symfony\Component\String\Slugger\AsciiSlugger;

class Utils
{
    #################################################################################################################################################

    public static function isProdEnv(): bool
    {
        return 'prod' === $_ENV['APP_ENV'];
    }

    public static function isTestEnv(): bool
    {
        return 'test' === $_ENV['APP_ENV'];
    }

    public static function isDevEnv(): bool
    {
        return 'dev' === $_ENV['APP_ENV'];
    }

    #################################################################################################################################################

    /**
     * @throws \Symfony\Contracts\HttpClient\Exception\ClientExceptionInterface
     * @throws \Symfony\Contracts\HttpClient\Exception\DecodingExceptionInterface
     * @throws \Symfony\Contracts\HttpClient\Exception\RedirectionExceptionInterface
     * @throws \Symfony\Contracts\HttpClient\Exception\ServerExceptionInterface
     * @throws \Symfony\Contracts\HttpClient\Exception\TransportExceptionInterface
     */
    public function reCaptchaIsValid(string $token): bool
    {
        $secret = $_ENV['RECAPTCHA_SECRET_KEY'] ?? null;
        if (empty($secret)) {
            return false;
        }

        $httpClient = HttpClient::create();
        $response   = $httpClient->request('POST', 'https://www.google.com/recaptcha/api/siteverify', [
            'body' => [
                'secret'   => $secret,
                'response' => $token
            ]
        ]);
        $response   = $response->toArray();

        return (isset($response['success']) && $response['success']);
    }

    public function sentryGetPublicKey(): string
    {
        preg_match('/https:\/\/(.*)@/i', $_ENV['SENTRY_DSN'], $matches);

        return $matches[1] ?? '';
    }

    public static function slug(mixed $string): string
    {
        $string  = str_replace('.', '', $string);
        $slugger = new AsciiSlugger(
            'en',
            [
                'en' => [
                    '&' => 'and',
                    '%' => 'percent',
                    '€' => 'euro',
                ],
            ]
        );

        return $slugger
            ->slug($string)
            ->lower()
            ->toString();
    }

    /**
     * @throws RandomException
     */
    public static function generateSalt(): string
    {
        return bin2hex(random_bytes(32))
            . sha1($_ENV['APP_SECRET'] ?? md5((string)microtime(true)))
            . sha1(uniqid());
    }

    public static function debug(mixed $data, bool $debug = false): void
    {
        if ($debug) {
            echo str_repeat("\x20", 4) . '[' . date('i:s') . ']' . str_repeat("\x20", 2) . $data . PHP_EOL;
        }
    }

    public function databaseFixMigration(): void
    {
        $migrationFilePathFinder = dirname(__FILE__, 3) . '/src/Migrations/' . date('Y') . '/' . date('m') . '/*.php';
        $migrationFilesPath      = glob($migrationFilePathFinder);

        foreach ($migrationFilesPath as $migrationFilePath) {
            $handle  = fopen($migrationFilePath, 'r');
            $content = '';
            if ($handle) {
                while (($line = fgets($handle)) !== false) {
                    $content .= $this->databaseFixer($line);
                }
                fclose($handle);
                file_put_contents($migrationFilePath, $content);
            } else {
                throw new \Exception(sprintf('Error opening file: %s', $migrationFilePath));
            }
        }
    }

    public function databaseFixer(string $line): string
    {
        if (!str_contains($line, 'CREATE TABLE')) {
            return $line;
        }

        // 1.1) Move `id` INT (and optionally `legacy_id`) immediately after `(`
        if (str_contains($line, 'id INT NOT NULL')) {
            $hasLegacy = (bool)preg_match('/,\s*legacy_id INT DEFAULT NULL\b/', $line);

            // remove `legacy_id` from the current position (if it exists)
            if ($hasLegacy) {
                $line = preg_replace('/,\s*legacy_id INT DEFAULT NULL\b/', '', $line);
            }

            // remove `id` from the current position without "breaking" the commas between neighbors
            // case 1: ", id INT NOT NULL," -> keep a single comma
            $line = preg_replace('/,\s*id INT NOT NULL\s*,/', ', ', $line);
            // case 2: ", id INT NOT NULL" (at the end of the list)
            $line = preg_replace('/,\s*id INT NOT NULL\b/', '', $line);
            // case 3: "(id INT NOT NULL, " (if it was the first)
            $line = preg_replace('/\(\s*id INT NOT NULL\s*,\s*/', '(', $line);

            // insert at the beginning
            $replacer = 'id INT NOT NULL, ' . ($hasLegacy ? 'legacy_id INT DEFAULT NULL, ' : '');
            $line     = preg_replace('/CREATE TABLE\s+([^\s]+)\s*\(/', 'CREATE TABLE $1 (' . $replacer, $line);

            // normalize double commas
            $line = preg_replace('/,\s*,+/', ', ', $line);
        }

        // 1.2) Move `id` BIGINT (and optionally `legacy_id`) immediately after `(`
        if (str_contains($line, 'id BIGINT NOT NULL')) {
            $hasLegacy = (bool)preg_match('/,\s*legacy_id INT DEFAULT NULL\b/', $line);

            // remove `legacy_id` from the current position (if it exists)
            if ($hasLegacy) {
                $line = preg_replace('/,\s*legacy_id INT DEFAULT NULL\b/', '', $line);
            }

            // remove `id` from the current position without "breaking" the commas between neighbors
            // case 1: ", id BIGINT NOT NULL," -> keep a single comma
            $line = preg_replace('/,\s*id BIGINT NOT NULL\s*,/', ', ', $line);
            // case 2: ", id BIGINT NOT NULL" (at the end of the list)
            $line = preg_replace('/,\s*id BIGINT NOT NULL\b/', '', $line);
            // case 3: "(id BIGINT NOT NULL, " (if it was the first)
            $line = preg_replace('/\(\s*id BIGINT NOT NULL\s*,\s*/', '(', $line);

            // insert at the beginning
            $replacer = 'id BIGINT NOT NULL, ' . ($hasLegacy ? 'legacy_id INT DEFAULT NULL, ' : '');
            $line     = preg_replace('/CREATE TABLE\s+([^\s]+)\s*\(/', 'CREATE TABLE $1 (' . $replacer, $line);

            // normalize double commas
            $line = preg_replace('/,\s*,+/', ', ', $line);
        }

        // 2) Move the *_at columns before PRIMARY KEY
        foreach (['created_at', 'updated_at', 'croned_at', 'synchronized_at', 'deleted_at'] as $column) {
            if (str_contains($line, ', ' . $column)) {
                if (preg_match(sprintf('/,\s*%s\s+([^,]*),/', preg_quote($column, '/')), $line, $matches)) {
                    $line = preg_replace(sprintf('/,\s*%s\s+([^,]*),/', preg_quote($column, '/')), ',', $line, 1);
                    $line = preg_replace('/,\s*PRIMARY KEY\s*\(/', $matches[0] . ' PRIMARY KEY (', $line, 1);
                }
            }
        }

        // 3) Ensure the comma before "meta" only if missing — insert a comma between a non-space character (that is NOT a comma) and "meta" when only spaces are in between
        $line = preg_replace('/(?<=\S)(?<!,)\s+(?=meta\b)/', ', ', $line);

        // 4) Normalize possible duplicate commas or spaces
        $line = preg_replace('/,\s*,+/', ', ', $line);
        $line = preg_replace('/\s{2,}/', ' ', $line);

        return $line;
    }

    #################################################################################################################################################

    public static function healthChecksIO(string $pingURL, bool $ignoreEnvironment = false): void
    {
        if (!$ignoreEnvironment && self::isDevEnv()) {
            return;
        }

        try {
            file_get_contents($pingURL);
        } catch (\Exception $e) {
            throw new \Exception("Health checks failed: {$pingURL}");
        }
    }

    public static function healthChecksIOStart(string $pingURL, string $rid, bool $ignoreEnvironment = false): void
    {
        if (!$ignoreEnvironment && self::isDevEnv()) {
            return;
        }

        $pingURL = trim($pingURL . '/start?rid=' . trim($rid));

        try {
            file_get_contents($pingURL);
        } catch (\Exception $e) {
            throw new \Exception("Health starts failed: {$pingURL}");
        }
    }

    public static function healthChecksIOFinish(string $pingURL, string $rid, bool $ignoreEnvironment = false): void
    {
        if (!$ignoreEnvironment && self::isDevEnv()) {
            return;
        }

        $pingURL = trim($pingURL . '?rid=' . trim($rid));

        try {
            file_get_contents($pingURL);
        } catch (\Exception $e) {
            throw new \Exception("Health finish failed: {$pingURL}");
        }
    }

    #################################################################################################################################################
}

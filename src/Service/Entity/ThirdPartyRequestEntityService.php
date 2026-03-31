<?php

namespace App\Service\Entity;

use App\Entity\ThirdPartyRequest;
use App\Repository\ThirdPartyRequestRepository;
use App\Utils\Utils;
use Doctrine\ORM\EntityManagerInterface;
use Sindla\Bundle\AuroraBundle\Utils\AuroraChronos\AuroraChronos;
use Sindla\Bundle\AuroraBundle\Utils\AuroraCookiesExtractor\AuroraCookiesExtractor;
use Symfony\Component\DependencyInjection\ParameterBag\ParameterBagInterface;
use Symfony\Component\HttpClient\Exception\InvalidArgumentException;
use Symfony\Component\HttpClient\HttpClient;
use Symfony\Contracts\HttpClient\Exception\ClientExceptionInterface;
use Symfony\Contracts\HttpClient\Exception\DecodingExceptionInterface;
use Symfony\Contracts\HttpClient\Exception\RedirectionExceptionInterface;
use Symfony\Contracts\HttpClient\Exception\ServerExceptionInterface;
use Symfony\Contracts\HttpClient\Exception\TransportExceptionInterface;
use Symfony\Contracts\HttpClient\HttpClientInterface;
use Symfony\Contracts\HttpClient\ResponseInterface;

class ThirdPartyRequestEntityService
{
    public ThirdPartyRequest $thirdPartyRequest;

    public function __construct(
        private readonly ParameterBagInterface       $parameterBag,
        private readonly EntityManagerInterface      $em,
        private readonly ThirdPartyRequestRepository $thirdPartyRequestRepository,
        public ?HttpClientInterface                  $httpClient = null,
        public ?ResponseInterface                    $response = null
    )
    {
        $this->httpClient ??= HttpClient::create();
    }

    public function persist(ThirdPartyRequest $thirdPartyRequest): ThirdPartyRequest
    {
        $this->thirdPartyRequestRepository->save($thirdPartyRequest);
        return $thirdPartyRequest;
    }

    public function createThirdPartyRequest(ThirdPartyRequest $thirdPartyRequest): self
    {
        $debug = filter_var($_ENV['LEGACY_ESTHETIC_LUX_CENTER_DEBUG'] ?? false, FILTER_VALIDATE_BOOLEAN);
        Utils::debug(__METHOD__ . '@' . __LINE__, $debug);

        // If the third party request it is persisted, then we use it
        if ($thirdPartyRequestCached = $this->em->getRepository(ThirdPartyRequest::class)->getCached($thirdPartyRequest)) {
            Utils::debug(__METHOD__ . '@' . __LINE__, $debug);
            $thirdPartyRequest = $thirdPartyRequestCached;
            $thirdPartyRequest->setCachedFromDatabase(true);
        }

        $this->thirdPartyRequestRepository->save($thirdPartyRequest);
        $this->thirdPartyRequest = $thirdPartyRequest;

        Utils::debug(__METHOD__ . '@' . __LINE__, $debug);

        return $this;
    }

    /**
     * This method first will try to get the response from the local file cache
     * If the local file cache is not found or expired, it will try to get the response from the database cache
     * If the database cache is not found or expired, it makes the third party API call
     *
     * @throws DecodingExceptionInterface
     * @throws ClientExceptionInterface
     * @throws ServerExceptionInterface
     * @throws \DateMalformedIntervalStringException
     * @throws RedirectionExceptionInterface
     * @throws TransportExceptionInterface
     * @throws \Exception
     */
    public function call(int $retryCount = 1): self
    {
        $debug = filter_var($_ENV['LEGACY_ESTHETIC_LUX_CENTER_DEBUG'] ?? false, FILTER_VALIDATE_BOOLEAN);

        Utils::debug(sprintf(
            PHP_EOL . PHP_EOL . '▶ %s %s',
            $this->thirdPartyRequest->getMethod(),
            $this->thirdPartyRequest->getBaseURL() . $this->thirdPartyRequest->getEndpoint() . ($this->thirdPartyRequest->getParameters() ? '?' . http_build_query($this->thirdPartyRequest->getParameters(), '', '&') : '')
        ), $debug);

        if ($retryCount > 1) {
            if ($retryCount > $this->thirdPartyRequest->getMaxRetries()) {
                throw new \Exception('Max retries reached!');
            }

            $delay = $this->thirdPartyRequest->getRetryDelaySeconds() * ($this->thirdPartyRequest->getRetryDelayMultiplier() ** ($retryCount - 1));

            $this->thirdPartyRequest
                ->setStatus(ThirdPartyRequest::STATUS_DELAYED);
            $this->thirdPartyRequestRepository->save($this->thirdPartyRequest);

            if ($debug) {
                Utils::debug(sprintf('Retry #%d/%d in %d seconds', $retryCount, $this->thirdPartyRequest->getMaxRetries(), $delay), $debug);
            }

            sleep($delay);
        }

        if (1 == $retryCount && $this->thirdPartyRequest->isCachedFromDatabase()) {
            Utils::debug(sprintf('✅ DB cache: %s ', $this->thirdPartyRequest->getHash()), $debug);
            $this->localStoragePut($debug);

            $this->thirdPartyRequest->setHits(1 + $this->thirdPartyRequest->getHits());
            $this->thirdPartyRequestRepository->save($this->thirdPartyRequest);

            return $this;
        } else {
            if (1 == $retryCount) {
                Utils::debug(sprintf('❌ DB valid cache not found (or ignored) for hash %s ', $this->thirdPartyRequest->getHash()), $debug);
            } else {
                Utils::debug(sprintf('❌ DB cache ignored - too many (%d) retries.', $retryCount), $debug);
            }
        }

        if (!$this->thirdPartyRequest->isIgnoreFileCache()) {
            if (1 == $retryCount && $this->localStorageGet($debug)) {
                Utils::debug(__METHOD__ . '@' . __LINE__, $debug);
                return $this;
            } else {
                Utils::debug(sprintf('❌ Local file cache not found or expired.'), $debug);
            }
        }

        try {
            Utils::debug(sprintf('♻  Calling the real third party services ...'), $debug);
            $this->thirdPartyRequest
                ->setStatus(ThirdPartyRequest::STATUS_PROCESSING)
                ->setRequests($this->thirdPartyRequest->getRequests() + 1)//->setCacheExpiresAt(new \DateTimeImmutable()->modify(sprintf('+%d seconds', $this->thirdPartyRequest->getDefaultCacheTTL())))
            ;
            $this->thirdPartyRequestRepository->save($this->thirdPartyRequest);

            $requestOptions            = [];
            $requestOptions['headers'] = $this->thirdPartyRequest->getHeaders();
            $requestOptions['body']    = $this->thirdPartyRequest->getBody();
            $requestUri                = $this->thirdPartyRequest->getBaseURL() . $this->thirdPartyRequest->getEndpoint() . ($this->thirdPartyRequest->getParameters() ? '?' . http_build_query($this->thirdPartyRequest->getParameters(), '', '&') : '');

            if (in_array('application/json', [$requestOptions['headers']['Content-Type'] ?? '', $requestOptions['headers']['content-type'] ?? ''])) {
                $requestOptions['body'] = json_encode($requestOptions['body']);
            }

            $this->thirdPartyRequest->addMeta(['HttpClient' => ['url' => $requestUri]]);
            $this->thirdPartyRequestRepository->save($this->thirdPartyRequest);

            $this->response = $this->httpClient->request(
                $this->thirdPartyRequest->getMethod(),
                $requestUri,
                $requestOptions
            );
        } catch (InvalidArgumentException $e) {
            $this->thirdPartyRequest->setStatus(ThirdPartyRequest::STATUS_CANCELLED);
            $this->thirdPartyRequestRepository->save($this->thirdPartyRequest);

            throw $e;

        } catch (ClientExceptionInterface|TransportExceptionInterface $e) {
            $this->response = $e->getResponse();
            if ($this->retryCodeRanges()) {
                Utils::debug(__METHOD__ . '@' . __LINE__ . ' 🔁', $debug);
                return $this->call(++$retryCount);
            }
        }

        $responseBody = null;
        try {
            $responseBody = $this->response->getContent(false);
        } catch (ClientExceptionInterface $e) {
            $this->response = $e->getResponse();
        } catch (TransportExceptionInterface $e) {
            return $this->call(++$retryCount);
        }

        $responseTimeSeconds      = (int)($this->response->getInfo()['total_time']);
        $responseTimeMilliseconds = (int)($this->response->getInfo()['total_time'] * 1000);

        $auroraCookiesExtractor = new AuroraCookiesExtractor();
        $cookies                = $auroraCookiesExtractor->extractFromSymfonyResponseInterface($this->response);
        $cookiesArray           = array_map(fn($cookie) => $cookie->toArray(), $cookies);

        $this->thirdPartyRequest
            ->setStatus(ThirdPartyRequest::STATUS_SUCCESS)
            ->setResponseStatusCode($this->response->getStatusCode())
            ->setResponseContentType($this->response->getHeaders(false)['content-type'][0] ?? null)
            ->setResponseHeaders($this->response->getHeaders(false))
            ->setResponseBody($responseBody)
            ->setRespondedAt($this->thirdPartyRequest->getCreatedAt()->add(new \DateInterval('PT' . $responseTimeSeconds . 'S')))
            ->setResponseTime($responseTimeMilliseconds)
            ->setResponseBodySize(strlen($responseBody))
            ->setResponseBodyNormalized(json_validate($responseBody) ? $this->response->toArray(false) : null)
            ->setResponseCookies($cookiesArray);

        if ($this->retryCodeRanges() || $this->retryMessages()) {
            Utils::debug(__METHOD__ . '@' . __LINE__ . ' 🔁', $debug);
            return $this->call(++$retryCount);
        }

        $this->thirdPartyRequestRepository->save($this->thirdPartyRequest);

        if (!$this->thirdPartyRequest->isIgnoreFileCache()) {
            $this->localStoragePut($debug);
        }

        return $this;
    }

    /**
     * @throws TransportExceptionInterface
     */
    private function retryCodeRanges(): bool
    {
        foreach ($this->thirdPartyRequest->getRetryCodeRanges() as [$min, $max]) {
            if ($this->response->getStatusCode() >= $min && $this->response->getStatusCode() <= $max) {
                $this->thirdPartyRequest
                    ->setResponseStatusCode($this->response->getStatusCode())
                    ->setStatus(ThirdPartyRequest::STATUS_FAILED)
                    ->addMeta([new \DateTimeImmutable()->format('Y-m-d H:i:s') => [
                        'message' => sprintf('Status code %s in range of %d - %d', $this->response->getStatusCode(), $min, $max)
                    ]]);
                $this->thirdPartyRequestRepository->save($this->thirdPartyRequest);
                return true;
            }
        }

        return false;
    }

    private function retryMessages(): bool
    {
        foreach ($this->thirdPartyRequest->getRetryMessages() as $message) {
            if (
                str_contains($this->thirdPartyRequest->getResponseBody(), $message)
                && !str_contains($this->thirdPartyRequest->getResponseBody(), "title: '{$message}!'")
            ) {
                $this->thirdPartyRequest
                    ->setStatus(ThirdPartyRequest::STATUS_FAILED)
                    ->addMeta([new \DateTimeImmutable()->format('Y-m-d H:i:s') => [
                        'message' => $message
                    ]]);
                $this->thirdPartyRequestRepository->save($this->thirdPartyRequest);
                return true;
            }
        }

        return false;
    }

    private function localStorageGet(bool $debug = false): bool
    {
        return $this->_localStorage(true, $debug);
    }

    private function localStoragePut(bool $debug = false): bool
    {
        return $this->_localStorage(false, $debug);
    }

    /**
     * @throws \DateMalformedStringException
     * @throws \Exception
     */
    private function _localStorage(bool $read = true, bool $debug = false): bool
    {
        if (!$this->thirdPartyRequest->isExpired(false)) {
            $localFileCacheSeconds = $this->thirdPartyRequest->shouldExpireIn();
            $auroraChronos         = new AuroraChronos();
            $cacheDir              = $this->parameterBag->get('kernel.project_dir') . '/var/tmp/legacy/esthetic-lux-center';
            $cacheFileName         = $this->thirdPartyRequest->getHash() . '.cache';
            $cacheFileAbsolutePath = $cacheDir . '/' . $cacheFileName;

            $fileCacheSize = 0;
            if ($fileCacheExist = file_exists($cacheFileAbsolutePath)) {
                $fileCacheSize = $this->fileSizeWithRetry($cacheFileAbsolutePath);
            }

            if ($read) {
                Utils::debug(sprintf('%s File cache: %s ', $fileCacheExist ? '✅' : '❌', $cacheFileName), $debug);

                if ($fileCacheExist && 0 !== $fileCacheSize) {
                    $fileTime       = filemtime($cacheFileAbsolutePath);
                    $fileDateTime   = new \DateTimeImmutable('@' . $fileTime);
                    $cacheExpiresAt = new \DateTimeImmutable()->modify("+ {$localFileCacheSeconds} seconds");

                    // --------------------------------------------------------
                    $now             = time();
                    $ttlExpired      = $fileDateTime->getTimestamp() + $this->thirdPartyRequest->getDefaultCacheTTL() < $now;
                    $absoluteExpired = $this->thirdPartyRequest->getCacheExpiresAt() instanceof \DateTimeInterface && $this->thirdPartyRequest->getCacheExpiresAt()->getTimestamp() < $now;
                    // --------------------------------------------------------

                    // Validate cache using the request's remaining lifetime, not the file age
                    if ($localFileCacheSeconds > 0 && !$ttlExpired && !$absoluteExpired) {
                        Utils::debug(sprintf(
                            'File cache is valid for %s, and will expire at %s (%s UTC)',
                            $auroraChronos->seconds2HMS($localFileCacheSeconds),
                            $cacheExpiresAt->setTimezone(new \DateTimeZone($_ENV['APP_TIMEZONE'] ?? date_default_timezone_get()))->format('Y-m-d H:i:s'),
                            $cacheExpiresAt->format('Y-m-d H:i:s')
                        ), $debug);

                        $responseContentBody = $this->fileGetContentsWithRetry($cacheFileAbsolutePath);

                        $this->thirdPartyRequest
                            ->setStatus(ThirdPartyRequest::STATUS_SUCCESS)
                            ->setResponseStatusCode(200)
                            ->setResponseContentType($this->guessContentType($responseContentBody))
                            ->setRespondedAt($fileDateTime)
                            ->setCachedFromDatabase(false)
                            ->setCachedFromLocalStorage(true)
                            ->setResponseBody($responseContentBody)
                            ->setResponseBodySize($this->fileSizeWithRetry($cacheFileAbsolutePath))
                            ->setResponseBodyNormalized(json_validate($responseContentBody) ? json_decode($responseContentBody, true) : null)
                            ->injectMeta(['localCacheFile' => $cacheFileAbsolutePath]);

                        if (!$this->thirdPartyRequest->isPersisted()) {
                            $this->thirdPartyRequest->setRequests(0);
                        }

                        $this->thirdPartyRequestRepository->save($this->thirdPartyRequest);
                        return true;
                    } else {
                        Utils::debug(sprintf(
                            'File cache (%s) is expired (remaining lifetime: %d seconds), will be deleted.',
                            $fileDateTime->format('Y-m-d H:i:s'),
                            $localFileCacheSeconds
                        ), $debug);
                        try {
                            unlink($cacheFileAbsolutePath);
                        } catch (\Exception $e) {
                            Utils::debug(sprintf('Cannot delete file cache: %s', $e->getMessage()), $debug);
                        }
                    }
                }
            } else {
                if (!is_dir($cacheDir)) {
                    mkdir($cacheDir, 0777, true);
                }

                if (!$fileCacheExist || 0 == $fileCacheSize) {
                    file_put_contents($cacheFileAbsolutePath, $this->thirdPartyRequest->getResponseBody());
                }

                return true;
            }
        }

        return false;
    }

    /**
     * Sanitize the endpoint name by removing the identifier value from the end of the endpoint name
     * Eg: '/service/get/52771' -> 'service/get'
     */
    public function endpointNameSanitizer(ThirdPartyRequest $thirdPartyRequest): void
    {
        if (
            $thirdPartyRequest->getIdentifierValue()
            && str_ends_with($thirdPartyRequest->getEndpointName(), "/{$thirdPartyRequest->getIdentifierValue()}")
        ) {
            $thirdPartyRequest->setEndpointName(substr($thirdPartyRequest->getEndpointName(), 0, -strlen("/{$thirdPartyRequest->getIdentifierValue()}")));
        }
    }

    public function save(): object
    {
        return $this->thirdPartyRequestRepository->save($this->thirdPartyRequest);
    }

    private function guessContentType(string $contentType): string
    {
        $content = trim($contentType);

        if ($content === '') {
            return 'text/plain';
        }

        if ((str_starts_with($content, '{') || str_starts_with($content, '[')) && json_validate($content)) {
            return 'application/json';
        }

        if (str_starts_with($content, '<')) {
            if (preg_match('/^\s*<!DOCTYPE\s+html/i', $content) || preg_match('/<html/i', $content)) {
                return 'text/html';
            }

            libxml_use_internal_errors(true);
            $simpleXml = simplexml_load_string($content);
            $errors    = libxml_get_errors();
            libxml_clear_errors();

            if ($simpleXml !== false && empty($errors)) {
                return 'application/xml';
            }
        }

        try {
            $finfo = new \finfo(FILEINFO_MIME_TYPE);
            $mime  = $finfo->buffer($content);

            if ($mime) {
                return $mime;
            }
        } catch (\Exception $e) {
        }

        return 'text/plain';
    }

    private function fileGetContentsWithRetry(string $cacheFileAbsolutePath, int $retries = 0): string
    {
        try {
            $responseContentBody = file_get_contents($cacheFileAbsolutePath);
        } catch (\Exception $e) {
            if ($retries < 3) {
                sleep(1 + $retries);
                return $this->fileGetContentsWithRetry($cacheFileAbsolutePath, 1 + $retries);
            } else {
                throw $e;
            }
        }

        return $responseContentBody;
    }

    private function fileSizeWithRetry(string $cacheFileAbsolutePath, int $retries = 0): int
    {
        try {
            $fileCacheSize = filesize($cacheFileAbsolutePath);
        } catch (\Exception $e) {
            if ($retries < 3) {
                sleep(1 + $retries);
                return $this->fileSizeWithRetry($cacheFileAbsolutePath, 1 + $retries);
            } else {
                throw $e;
            }
        }

        return $fileCacheSize;
    }
}

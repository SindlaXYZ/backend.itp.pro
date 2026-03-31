<?php

namespace App\Entity;

use App\Config\Constants;
use App\EventSubscriber\Entity\ThirdPartyRequestEventSubscriber;
use App\Repository\ThirdPartyRequestRepository;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Identifiable\IdentifiableBigintNonNullable;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Misc\MetaTrait;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableCreatedAndUpdated;
use Sindla\Bundle\AuroraBundle\Utils\AuroraArray\AuroraArray;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * @see ThirdPartyRequestEventSubscriber
 */
#[ORM\Table(
    name   : 'third_party_request',
    options: [
        'comment' => 'Third party requests'
    ]
)]
#[ORM\Entity(repositoryClass: ThirdPartyRequestRepository::class)]
#[ORM\Index(name: 'IDX_third_party_request_third_party', columns: ['third_party'])]
#[ORM\Index(name: 'IDX_third_party_request_endpoint_name', columns: ['endpoint_name'])]
#[ORM\Index(name: 'IDX_third_party_request_status', columns: ['status'])]
#[ORM\Index(name: 'IDX_third_party_request_identifier_key', columns: ['identifier_key'])]
#[ORM\Index(name: 'IDX_third_party_request_identifier_value', columns: ['identifier_value'])]
#[ORM\HasLifecycleCallbacks]
#[Assert\EnableAutoMapping]
class ThirdPartyRequest
{
    use IdentifiableBigintNonNullable;
    use MetaTrait;
    use TimestampableCreatedAndUpdated;

    public final const string STATUS_QUEUED     = 'queued';
    public final const string STATUS_PROCESSING = 'processing';
    public final const string STATUS_SUCCESS    = 'success';
    public final const string STATUS_FAILED     = 'failed';
    public final const string STATUS_CANCELLED  = 'cancelled';
    public final const string STATUS_RETRYING   = 'retrying';
    public final const string STATUS_DELAYED    = 'delayed';
    public final const string STATUS_TIMED_OUT  = 'timed_out';

    public final const int DEFAULT_CACHE_TTL          = 60 * 60 * 24;
    public final const int DEFAULT_DB_CACHE_SECONDS   = 60 * 60 * 24;
    public final const int DEFAULT_FILE_CACHE_SECONDS = 60 * 60 * 24;

    public final const string THIRD_PARTY_APP_LOGBOX_RO                       = 'app.logbox.ro';
    public final const string THIRD_PARTY_COMPANERO_RO                        = 'companero.ro';
    public final const string THIRD_PARTY_COMPANERO_RO_ENDPOINT_REPORT_SEARCH = 'ReportSearch';

    public final const string THIRD_PARTY_WEBSERVICESP_ANAF_RO                    = 'webservicesp.anaf.ro';
    public final const string THIRD_PARTY_WEBSERVICESP_ANAF_RO_ENDPOINT_VAT_PAYER = 'PlatitorTvaRest';
    public final const string THIRD_PARTY_WEBSERVICESP_ANAF_RO_ENDPOINT_BALANCE   = 'bilant';

    #[ORM\Column(name: 'third_party', type: Types::STRING, length: 255, nullable: false, options: ['comment' => 'Third party domain, eg: api.example.com'])]
    #[Assert\NotBlank]
    private string $thirdParty;

    #[ORM\Column(name: 'method', type: Types::STRING, length: 255, nullable: false, options: ['comment' => 'Request HTTP method: GET, POST, PUT, DELETE, etc'])]
    #[Assert\NotBlank]
    private string $method;

    #[ORM\Column(name: 'base_url', type: Types::STRING, length: 255, nullable: false, options: ['comment' => 'Request URL, eg: https://api.example.com'])]
    #[Assert\NotBlank]
    private string $baseURL;

    #[ORM\Column(name: 'endpoint_name', type: Types::STRING, length: 255, nullable: false, options: ['comment' => 'Request endpoint name, eg: PlatitorTvaRest for /api/PlatitorTvaRest/v9/tva'])]
    #[Assert\NotBlank]
    private string $endpointName;

    #[ORM\Column(name: 'endpoint', type: Types::STRING, length: 255, nullable: false, options: ['comment' => 'Request endpoint, eg: /api/PlatitorTvaRest/v9/tva'])]
    #[Assert\NotBlank]
    private string $endpoint;

    #[ORM\Column(name: 'headers', type: Types::JSON, nullable: true, options: ['comment' => 'Request headers'])]
    private ?array $headers = null;

    #[ORM\Column(name: 'options', type: Types::JSON, nullable: false, options: ['comment' => 'HttpClient options, eg: [max_redirects => 3]'])]
    private array $options = [];

    #[ORM\Column(name: 'parameters', type: Types::JSON, nullable: true)]
    private ?array $parameters = null;

    #[ORM\Column(name: 'body', type: Types::TEXT, nullable: true)]
    private string|array|null $body = null;

    #[ORM\Column(name: 'identifier_key', type: Types::STRING, length: 255, nullable: true, options: ['comment' => 'Identifier key for the request, eg: cnp, id, cui, taxid, etc'])]
    private ?string $identifierKey = null;

    #[ORM\Column(name: 'identifier_value', type: Types::STRING, length: 255, nullable: true, options: ['comment' => 'Identifier value for the request, eg: 1234567890123, 1, 8634852474, etc'])]
    private ?string $identifierValue = null;

    #[ORM\Column(name: 'hash', type: Types::STRING, length: 255, nullable: false)]
    private ?string $hash = null;

    #[ORM\Column(name: 'status', type: Types::STRING, length: 24, nullable: false)]
    private string $status = self::STATUS_QUEUED;

    #[ORM\Column(name: 'requests', type: Types::SMALLINT, nullable: false, options: ['default' => 0, 'unsigned' => true, 'comment' => 'Number of the requests (retries)'])]
    #[Assert\PositiveOrZero]
    private int $requests = 0;

    #[ORM\Column(name: 'default_cache_ttl', type: Types::BIGINT, nullable: false, options: ['default' => 60 * 60 * 24, 'unsigned' => true, 'comment' => 'Default time-to-live in seconds for database query cache and files cache (0 = disabled) - used when no specific TTL is set for a specific request (eg: when using the "cache" option in the HttpClient'])]
    #[Assert\PositiveOrZero]
    private int $defaultCacheTTL = self::DEFAULT_CACHE_TTL;

    #[ORM\Column(name: 'cache_expires_at', type: Types::DATETIME_IMMUTABLE, nullable: true, options: ['comment' => 'Absolute timestamp when this cached third-party response becomes invalid and must be refreshed.'])]
    #[Assert\NotBlank]
    private ?\DateTimeImmutable $cacheExpiresAt = null;

    #[ORM\Column(name: 'hits', type: Types::INTEGER, nullable: false, options: ['default' => 0, 'unsigned' => true, 'comment' => 'Number of cache hits (0 = no cache, 1..n = how many times the cache was hit)'])]
    #[Assert\PositiveOrZero]
    private int $hits = 0;

    #[ORM\Column(name: 'response_status_code', type: Types::INTEGER, length: 3, nullable: true)]
    private ?int $responseStatusCode = null;

    #[ORM\Column(name: 'response_content_type', type: Types::STRING, length: 255, nullable: true)]
    private ?string $responseContentType = null;

    #[ORM\Column(name: 'response_headers', type: Types::JSON, nullable: true)]
    private ?array $responseHeaders = null;

    #[ORM\Column(name: 'response_cookies', type: Types::JSON, nullable: true)]
    private ?array $responseCookies = null;

    #[ORM\Column(name: 'response_body', type: Types::TEXT, nullable: true)]
    private ?string $responseBody = null;

    #[ORM\Column(name: 'response_body_size', type: Types::INTEGER, length: 3, nullable: true, options: ['default' => 0, 'unsigned' => true, 'comment' => 'Response body size in bytes'])]
    private ?int $responseBodySize = 0;

    #[ORM\Column(name: 'response_body_normalized', type: Types::JSON, nullable: true)]
    private ?array $responseBodyNormalized = null;

    #[ORM\Column(name: 'response_body_date', type: Types::DATETIME_IMMUTABLE, nullable: true, options: ['comment' => 'Date extracted from API response body (used for dynamic cache TTL calculation)'])]
    private ?\DateTimeImmutable $responseBodyDate = null;

    #[ORM\Column(type: 'datetime_immutable', nullable: true)]
    private ?\DateTimeInterface $respondedAt = null;

    #[ORM\Column(name: 'response_time', type: Types::INTEGER, nullable: true, options: ['unsigned' => true, 'comment' => 'Response time in milliseconds'])]
    private ?int $responseTime = null;

    public bool   $ignoreFileCache        = false;
    private int   $defaultCacheSeconds    = 60 * 60 * 24;
    private bool  $cachedFromDatabase     = false; // This is only the default value but will be overridden by the setter
    private bool  $cachedFromLocalStorage = false; // This is only the default value but will be overridden by the setter
    private int   $maxRetries             = 5;     // maximum number of retries for the same HTTP request
    private int   $retryDelaySeconds      = 10;    // seconds
    private int   $retryDelayMultiplier   = 2;     // formula: retryDelaySeconds * (retryDelayMultiplier ^ (retryCount - 1))
    private array $retryCodeRanges        = [[400, 599]];
    private array $retryMessages
                                          = [
            'Ceva nu funcționează cum trebuie',
            'CSRF este invalid',
            'A apărut o eroare',
            'Invalid credentials'
        ];

    ###################################################################################################################################################################################################
    ###   Custom methods   ############################################################################################################################################################################

    public function __construct(string $url)
    {
        if (filter_var($url, FILTER_VALIDATE_URL)) {
            $parsedUrl = parse_url($url);
            $host      = $parsedUrl['host'] ?? '';
            $baseUrl   = $host ? $parsedUrl['scheme'] . '://' . $host : '';
            $query     = $parsedUrl['query'] ?? '';
            parse_str($query, $queryArray);

            $this
                ->setThirdParty($host)
                ->setMethod(Constants::HTTP_GET)
                ->setBaseURL($baseUrl)
                ->setEndpointName(
                    isset($parsedUrl['path']) ? trim($parsedUrl['path'], '/') : ''
                )
                ->setEndpoint(
                    isset($parsedUrl['path']) ? '/' . ltrim($parsedUrl['path'], '/') : ''
                )
                ->setParameters(
                    !empty($queryArray) ? $queryArray : null
                );
        }
    }

    public function computeHash(): string
    {
        $auroraArray = new AuroraArray();

        $headers = $this->getHeaders();
        if (is_array($headers)) {
            unset($headers['Cookie']);
        }

        $body         = $this->getBody();
        $bodyAsString = null;

        if (is_array($body)) {
            unset($body['_csrf_token']);
            ksort($body);
            $bodyAsString = json_encode($body);
        } else if (true === json_validate($body ?? '')) {
            $bodyAsArray = json_decode($body, true);
            ksort($bodyAsArray);
            $bodyAsString = json_encode($bodyAsArray);
        }

        return
            hash(
                'sha256',
                $this->getThirdParty()
                . $this->getMethod()
                . $this->getBaseURL()
                . $this->getEndpoint()
                . ($headers ? json_encode($auroraArray->kSortRecursive($headers)) : '')
                . ($this->getParameters() ? json_encode($auroraArray->kSortRecursive($this->getParameters())) : '')
                . $bodyAsString
            );
    }

    public function getHash(): string
    {
        if ($this->hash === null || $this->hash === '') {
            $this->hash = $this->computeHash();
        }
        return $this->hash;
    }

    public function setThirdParty(string $thirdParty): self
    {
        $parsedUrl        = parse_url($thirdParty);
        $this->thirdParty = $parsedUrl['host'] ?? $parsedUrl['path'];
        return $this;
    }

    public function setBaseURL(string $baseURL): self
    {
        if (filter_var($baseURL, FILTER_VALIDATE_URL)) {
            $parsedUrl = parse_url($baseURL);
            $host      = $parsedUrl['host'] ?? '';
            $baseUrl   = $host ? $parsedUrl['scheme'] . '://' . $host : '';

            $this->baseURL = $baseUrl;
        } else {
            $this->baseURL = rtrim($baseURL, '/');
        }

        return $this;
    }

    public function setEndpointName(string $endpointName): self
    {
        $this->endpointName = trim($endpointName, '/');
        return $this;
    }

    public function setEndpoint(string $endpoint): self
    {
        $this->endpoint = '/' . ltrim($endpoint, '/');
        return $this;
    }

    public function getBody(): array|string|null
    {
        if (is_null($this->body)) {
            return null;
        }

        return is_array($this->body) ? $this->body : (json_validate($this->body) ? json_decode($this->body, true) : $this->body);
    }

    public function setBody(array|string|null $body): self
    {
        if (is_null($body)) {
            $this->body = null;
            return $this;
        }

        $this->body = is_array($body) ? json_encode($body) : $body;
        return $this;
    }

    public function isCached(): bool
    {
        return $this->cachedFromDatabase || $this->cachedFromLocalStorage;
    }

    public function isExpired(bool $nullRespondedAtMeanExpired = true): bool
    {
        // If responded_at is null, then means the request is expired
        if ($nullRespondedAtMeanExpired && !$this->getRespondedAt()) {
            return true;
        }

        $now             = time();
        $ttlExpired      = $nullRespondedAtMeanExpired && ($this->getRespondedAt()->getTimestamp() + $this->getDefaultCacheTTL()) < $now;
        $absoluteExpired = $this->getCacheExpiresAt() instanceof \DateTimeInterface && $this->getCacheExpiresAt()->getTimestamp() < $now;

        return $ttlExpired || $absoluteExpired;
    }

    public function shouldExpireIn(): int
    {
        $now = time();

        if ($this->getCacheExpiresAt() instanceof \DateTimeInterface) {
            return max(0, $this->getCacheExpiresAt()->getTimestamp() - $now);
        }

        if (!in_array($this->getStatus(), [self::STATUS_QUEUED, self::STATUS_PROCESSING]) && $this->getRespondedAt() instanceof \DateTimeInterface) {
            return max(0, $this->getRespondedAt()->getTimestamp() + $this->getDefaultCacheTTL() - $now);
        }

        return $this->getDefaultCacheTTL();
    }

    public function isIgnoreFileCache(): bool
    {
        return $this->ignoreFileCache;
    }

    public function setIgnoreFileCache(bool $ignoreFileCache): self
    {
        $this->ignoreFileCache = $ignoreFileCache;
        return $this;
    }

    ###################################################################################################################################################################################################
    ###   IDE generated setters & getters   ###########################################################################################################################################################

    public function getThirdParty(): string
    {
        return $this->thirdParty;
    }

    public function getMethod(): string
    {
        return $this->method;
    }

    public function setMethod(string $method): self
    {
        $this->method = $method;
        return $this;
    }

    public function getBaseURL(): string
    {
        return $this->baseURL;
    }

    public function getEndpointName(): string
    {
        return $this->endpointName;
    }

    public function getEndpoint(): string
    {
        return $this->endpoint;
    }

    public function getOptions(): array
    {
        return $this->options;
    }

    public function setOptions(array $options): self
    {
        $this->options = $options;
        return $this;
    }

    public function addOption(mixed $option): self
    {
        $this->options[] = $option;
        return $this;
    }

    public function mergeOptions(array $options): self
    {
        $this->options = (is_array($this->options) ? array_merge($this->options, $options) : $options);
        return $this;
    }

    public function removeOption(mixed $option): self
    {
        $index = array_search($option, $this->options, true);
        if ($index !== false) {
            array_splice($this->options, $index, 1);
        }
        return $this;
    }

    public function getHeaders(): ?array
    {
        return $this->headers;
    }

    public function setHeaders(?array $headers): self
    {
        $this->headers = $headers;
        return $this;
    }

    public function getParameters(): ?array
    {
        return $this->parameters;
    }

    public function setParameters(?array $parameters): self
    {
        $this->parameters = $parameters;
        return $this;
    }

    public function getIdentifierKey(): ?string
    {
        return $this->identifierKey;
    }

    public function setIdentifierKey(?string $identifierKey): self
    {
        $this->identifierKey = $identifierKey;
        return $this;
    }

    public function getIdentifierValue(): ?string
    {
        return $this->identifierValue;
    }

    public function setIdentifierValue(?string $identifierValue): self
    {
        $this->identifierValue = $identifierValue;
        return $this;
    }

    public function setHash(string $hash): self
    {
        $this->hash = $hash;
        return $this;
    }

    public function getStatus(): string
    {
        return $this->status;
    }

    public function setStatus(string $status): self
    {
        $this->status = $status;
        return $this;
    }

    public function getRequests(): int
    {
        return $this->requests;
    }

    public function setRequests(int $requests): self
    {
        $this->requests = $requests;
        return $this;
    }

    public function getDefaultCacheTTL(): int
    {
        return $this->defaultCacheTTL;
    }

    public function setDefaultCacheTTL(int $defaultCacheTTL): self
    {
        $this->defaultCacheTTL = $defaultCacheTTL;
        return $this;
    }

    public function getCacheExpiresAt(): ?\DateTimeImmutable
    {
        return $this->cacheExpiresAt;
    }

    public function setCacheExpiresAt(?\DateTimeImmutable $cacheExpiresAt): self
    {
        $this->cacheExpiresAt = $cacheExpiresAt;
        return $this;
    }

    public function getHits(): int
    {
        return $this->hits;
    }

    public function setHits(int $hits): self
    {
        $this->hits = $hits;
        return $this;
    }

    public function getResponseStatusCode(): ?int
    {
        return $this->responseStatusCode;
    }

    public function setResponseStatusCode(?int $responseStatusCode): self
    {
        $this->responseStatusCode = $responseStatusCode;
        return $this;
    }

    public function getResponseContentType(): ?string
    {
        return $this->responseContentType;
    }

    public function setResponseContentType(?string $responseContentType): self
    {
        $this->responseContentType = $responseContentType;
        return $this;
    }

    public function getResponseHeaders(): ?array
    {
        return $this->responseHeaders;
    }

    public function setResponseHeaders(?array $responseHeaders): self
    {
        $this->responseHeaders = $responseHeaders;
        return $this;
    }

    public function getResponseCookies(): ?array
    {
        return $this->responseCookies;
    }

    public function setResponseCookies(?array $responseCookies): self
    {
        $this->responseCookies = $responseCookies;
        return $this;
    }

    public function getResponseBody(): ?string
    {
        return $this->responseBody;
    }

    public function setResponseBody(?string $responseBody): self
    {
        $this->responseBody = $responseBody;
        return $this;
    }

    public function getResponseBodySize(): ?int
    {
        return $this->responseBodySize;
    }

    public function setResponseBodySize(?int $responseBodySize): self
    {
        $this->responseBodySize = $responseBodySize;
        return $this;
    }

    public function getResponseBodyNormalized(): ?array
    {
        return $this->responseBodyNormalized;
    }

    public function setResponseBodyNormalized(?array $responseBodyNormalized): self
    {
        $this->responseBodyNormalized = $responseBodyNormalized;
        return $this;
    }

    public function getResponseBodyDate(): ?\DateTimeImmutable
    {
        return $this->responseBodyDate;
    }

    public function setResponseBodyDate(?\DateTimeImmutable $responseBodyDate): self
    {
        $this->responseBodyDate = $responseBodyDate;
        return $this;
    }

    public function getRespondedAt(): ?\DateTimeInterface
    {
        return $this->respondedAt;
    }

    public function setRespondedAt(?\DateTimeInterface $respondedAt): self
    {
        $this->respondedAt = $respondedAt;
        return $this;
    }

    public function getResponseTime(): ?int
    {
        return $this->responseTime;
    }

    public function setResponseTime(?int $responseTime): self
    {
        $this->responseTime = $responseTime;
        return $this;
    }

    public function getDefaultCacheSeconds(): int
    {
        return $this->defaultCacheSeconds;
    }

    public function setDefaultCacheSeconds(int $defaultCacheSeconds): self
    {
        $this->defaultCacheSeconds = $defaultCacheSeconds;
        return $this;
    }

    public function isCachedFromDatabase(): bool
    {
        return $this->cachedFromDatabase;
    }

    public function setCachedFromDatabase(bool $cachedFromDatabase): self
    {
        $this->cachedFromDatabase = $cachedFromDatabase;
        return $this;
    }

    public function isCachedFromLocalStorage(): bool
    {
        return $this->cachedFromLocalStorage;
    }

    public function setCachedFromLocalStorage(bool $cachedFromLocalStorage): self
    {
        $this->cachedFromLocalStorage = $cachedFromLocalStorage;
        return $this;
    }

    public function getMaxRetries(): int
    {
        return $this->maxRetries;
    }

    public function setMaxRetries(int $maxRetries): self
    {
        $this->maxRetries = $maxRetries;
        return $this;
    }

    public function getRetryDelaySeconds(): int
    {
        return $this->retryDelaySeconds;
    }

    public function setRetryDelaySeconds(int $retryDelaySeconds): self
    {
        $this->retryDelaySeconds = $retryDelaySeconds;
        return $this;
    }

    public function getRetryDelayMultiplier(): int
    {
        return $this->retryDelayMultiplier;
    }

    public function setRetryDelayMultiplier(int $retryDelayMultiplier): self
    {
        $this->retryDelayMultiplier = $retryDelayMultiplier;
        return $this;
    }

    public function getRetryCodeRanges(): array
    {
        return $this->retryCodeRanges;
    }

    public function setRetryCodeRanges(array $retryCodeRanges): self
    {
        $this->retryCodeRanges = $retryCodeRanges;
        return $this;
    }

    public function addRetryCodeRange(mixed $retryCodeRange): self
    {
        $this->retryCodeRanges[] = $retryCodeRange;
        return $this;
    }

    public function mergeRetryCodeRanges(array $retryCodeRanges): self
    {
        $this->retryCodeRanges = (is_array($this->retryCodeRanges) ? array_merge($this->retryCodeRanges, $retryCodeRanges) : $retryCodeRanges);
        return $this;
    }

    public function removeRetryCodeRange(mixed $retryCodeRange): self
    {
        $index = array_search($retryCodeRange, $this->retryCodeRanges, true);
        if ($index !== false) {
            array_splice($this->retryCodeRanges, $index, 1);
        }
        return $this;
    }

    public function getRetryMessages(): array
    {
        return $this->retryMessages;
    }

    public function setRetryMessages(array $retryMessages): self
    {
        $this->retryMessages = $retryMessages;
        return $this;
    }

    public function addRetryMessage(mixed $retryMessage): self
    {
        $this->retryMessages[] = $retryMessage;
        return $this;
    }

    public function mergeRetryMessages(array $retryMessages): self
    {
        $this->retryMessages = (is_array($this->retryMessages) ? array_merge($this->retryMessages, $retryMessages) : $retryMessages);
        return $this;
    }

    public function removeRetryMessage(mixed $retryMessage): self
    {
        $index = array_search($retryMessage, $this->retryMessages, true);
        if ($index !== false) {
            array_splice($this->retryMessages, $index, 1);
        }
        return $this;
    }
}

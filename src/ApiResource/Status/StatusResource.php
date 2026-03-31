<?php

namespace App\ApiResource\Status;

use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use Symfony\Component\Serializer\Attribute\Groups;

#[ApiResource(
    shortName           : 'Status',
    operations          : [
        new Get(
            uriTemplate: '/status',
            description: 'Get application operational status with geo information',
            provider   : StatusStateProvider::class
        )
    ],
    normalizationContext: ['groups' => [self::GROUP_READ]]
)]
class StatusResource
{
    final const string GROUP_READ = __CLASS__ . ':read';

    #[Groups([self::GROUP_READ])]
    public string $message = 'Operational';

    #[Groups([self::GROUP_READ])]
    public string $ip;

    #[Groups([self::GROUP_READ])]
    public ?string $countryCode;

    #[Groups([self::GROUP_READ])]
    public ?string $countyName;

    #[Groups([self::GROUP_READ])]
    public ?string $cityName;

    public function __construct()
    {

    }

    public function getMessage(): string
    {
        return $this->message;
    }

    public function setMessage(string $message): self
    {
        $this->message = $message;
        return $this;
    }

    public function getIp(): string
    {
        return $this->ip;
    }

    public function setIp(string $ip): self
    {
        $this->ip = $ip;
        return $this;
    }

    public function getCountryCode(): ?string
    {
        return $this->countryCode;
    }

    public function setCountryCode(?string $countryCode): self
    {
        $this->countryCode = $countryCode;
        return $this;
    }

    public function getCountyName(): ?string
    {
        return $this->countyName;
    }

    public function setCountyName(?string $countyName): self
    {
        $this->countyName = $countyName;
        return $this;
    }

    public function getCityName(): ?string
    {
        return $this->cityName;
    }

    public function setCityName(?string $cityName): self
    {
        $this->cityName = $cityName;
        return $this;
    }
}

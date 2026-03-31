<?php

namespace App\ApiResource\Status;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProviderInterface;
use Doctrine\ORM\EntityManagerInterface;
use Sindla\Bundle\AuroraBundle\Utils\AuroraClient\AuroraClient;
use Sindla\Bundle\AuroraBundle\Utils\AuroraIP\AuroraIP;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\HttpFoundation\RequestStack;

/**
 * @implements ProviderInterface<StatusResource>
 */
class StatusStateProvider implements ProviderInterface
{
    public function __construct(
        protected EntityManagerInterface $em,
        #[Autowire(service: 'aurora.client')]
        protected AuroraClient           $auroraClient,
        protected RequestStack           $requestStack
    )
    {
    }

    public function provide(Operation $operation, array $uriVariables = [], array $context = []): StatusResource
    {
        $this->validateEnvironment();

        $request = $this->requestStack->getCurrentRequest();
        if (!$request) {
            throw new \RuntimeException('No current request available');
        }

        $agentIP = new AuroraIP()->ip($request);

        try {
            $countryCode = $this->auroraClient->ip2CountryCode($agentIP);
        } catch (\Throwable $e) {
            $countryCode = null;
        }

        try {
            $countyName = $this->auroraClient->ip2CityCounty($agentIP);
        } catch (\Throwable $e) {
            $countyName = null;
        }

        try {
            $cityName = $this->auroraClient->ip2CityName($agentIP);
        } catch (\Throwable $e) {
            $cityName = null;
        }

        return new StatusResource()
            ->setMessage('Operational')
            ->setIp($agentIP)
            ->setCountryCode($countryCode)
            ->setCountyName($countyName)
            ->setCityName($cityName);
    }

    private function validateEnvironment(): void
    {
        if (
            !isset($_ENV['SINDLA_AURORA_GEO_LITE2_COUNTRY'])
            || !filter_var($_ENV['SINDLA_AURORA_GEO_LITE2_COUNTRY'], FILTER_VALIDATE_BOOLEAN)
        ) {
            throw new \Exception('SINDLA_AURORA_GEO_LITE2_COUNTRY=true is not defined in .env[.local]');
        }
    }
}

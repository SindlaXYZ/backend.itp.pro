<?php

namespace App\Security;

use DH\Auditor\Security\SecurityProviderInterface;
use Sindla\Bundle\AuroraBundle\Utils\AuroraIP\AuroraIP;
use Symfony\Bundle\SecurityBundle\Security\FirewallMap;
use Symfony\Component\HttpFoundation\RequestStack;

readonly class AuditorSecurityProvider implements SecurityProviderInterface
{
    public function __construct(
        private RequestStack $requestStack,
        private FirewallMap  $firewallMap,
        private AuroraIP     $auroraIP
    )
    {
    }

    public function __invoke(): array
    {
        $clientIp     = null;
        $firewallName = null;

        $request = $this->requestStack->getCurrentRequest();

        if (null !== $request) {
            $firewallConfig = $this->firewallMap->getFirewallConfig($request);
            $clientIp       = $this->auroraIP->ip($request);
            $firewallName   = $firewallConfig?->getName();
        }

        return [$clientIp, $firewallName];
    }
}

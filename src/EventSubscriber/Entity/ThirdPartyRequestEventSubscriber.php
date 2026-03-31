<?php

namespace App\EventSubscriber\Entity;

use App\Entity\ThirdPartyRequest;
use App\Service\Entity\ThirdPartyRequestEntityService;
use Doctrine\Bundle\DoctrineBundle\Attribute\AsDoctrineListener;
use Doctrine\ORM\Event\PreUpdateEventArgs;
use Doctrine\ORM\Events;

#[AsDoctrineListener(event: Events::preUpdate)]
readonly class ThirdPartyRequestEventSubscriber
{
    public function __construct(
        private ThirdPartyRequestEntityService $thirdPartyRequestEntityService
    )
    {
    }

    public function preUpdate(PreUpdateEventArgs $event): void
    {
        $thirdPartyRequest = $event->getObject();

        if (!$thirdPartyRequest instanceof ThirdPartyRequest) {
            return;
        }

        $this->thirdPartyRequestEntityService->endpointNameSanitizer($thirdPartyRequest);
    }
}

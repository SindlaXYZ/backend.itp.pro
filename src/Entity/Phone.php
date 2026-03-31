<?php

namespace App\Entity;

use App\Repository\PhoneRepository;
use Doctrine\ORM\Mapping as ORM;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Identifiable\IdentifiableIntNonNullable;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableCreatedAndUpdated;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableCroned;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableTranslated;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Table(name: 'phone')]
#[ORM\Entity(repositoryClass: PhoneRepository::class)]
#[ORM\HasLifecycleCallbacks]
#[Assert\EnableAutoMapping]
class Phone
{
    use IdentifiableIntNonNullable;
    use TimestampableCreatedAndUpdated;
    use TimestampableCroned;

    #[ORM\ManyToOne(targetEntity: User::class, inversedBy: 'phones')]
    #[ORM\JoinColumn(name: 'user_id', referencedColumnName: 'id', nullable: true, onDelete: 'SET NULL')]
    private ?User $user = null;

    ###################################################################################################################################################################################################
    ###   Custom methods   ############################################################################################################################################################################

    ###################################################################################################################################################################################################
    ###   IDE generated setters & getters   ###########################################################################################################################################################
}

<?php

namespace App\Entity;

use App\Repository\AddressRepository;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Identifiable\IdentifiableIntNonNullable;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Misc\MetaTrait;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableCreatedAndUpdated;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableDeletedNullable;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Table(name: 'address')]
#[ORM\Entity(repositoryClass: AddressRepository::class)]
#[ORM\HasLifecycleCallbacks]
#[Assert\EnableAutoMapping]
class Address
{
    use IdentifiableIntNonNullable;
    use MetaTrait;
    use TimestampableCreatedAndUpdated;
    use TimestampableDeletedNullable;

    #[ORM\ManyToOne(targetEntity: City::class, inversedBy: 'addresses')]
    #[ORM\JoinColumn(name: 'city_id', referencedColumnName: 'id', nullable: false, onDelete: 'RESTRICT')]
    private City $city;

    #[ORM\Column(name: 'street', type: Types::STRING, length: 255, nullable: false)]
    #[Assert\NotBlank]
    private string $street;

    #[ORM\Column(name: 'number', type: Types::STRING, length: 50, nullable: true)]
    private ?string $number = null;

    #[ORM\Column(name: 'building', type: Types::STRING, length: 50, nullable: true, options: ['comment' => 'Building/Block'])]
    private ?string $building = null;

    #[ORM\Column(name: 'entrance', type: Types::STRING, length: 10, nullable: true)]
    private ?string $entrance = null;

    #[ORM\Column(name: 'floor', type: Types::STRING, length: 10, nullable: true)]
    private ?string $floor = null;

    #[ORM\Column(name: 'apartment', type: Types::STRING, length: 20, nullable: true)]
    private ?string $apartment = null;

    #[ORM\Column(name: 'postal_code', type: Types::STRING, length: 20, nullable: true)]
    private ?string $postalCode = null;

    #[ORM\Column(name: 'latitude', type: Types::DECIMAL, precision: 10, scale: 8, nullable: true)]
    private ?string $latitude = null;

    #[ORM\Column(name: 'longitude', type: Types::DECIMAL, precision: 11, scale: 8, nullable: true)]
    private ?string $longitude = null;

    ###################################################################################################################################################################################################
    ###   Custom methods   ############################################################################################################################################################################

    public function __toString(): string
    {
        $parts = [$this->street];

        if ($this->number) {
            $parts[] = "nr. {$this->number}";
        }

        if ($this->building) {
            $parts[] = "bl. {$this->building}";
        }

        if ($this->entrance) {
            $parts[] = "sc. {$this->entrance}";
        }

        if ($this->apartment) {
            $parts[] = "ap. {$this->apartment}";
        }

        return implode(', ', $parts);
    }

    ###################################################################################################################################################################################################
    ###   IDE generated setters & getters   ###########################################################################################################################################################
}

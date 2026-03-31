<?php

namespace App\Entity;

use App\Repository\CompanyAddressRepository;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Identifiable\IdentifiableIntNonNullable;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Misc\MetaTrait;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableCreatedAndUpdated;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableDeletedNullable;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Table(name: 'company_address')]
#[ORM\Entity(repositoryClass: CompanyAddressRepository::class)]
#[ORM\UniqueConstraint(name: 'UNIQ_company_address', columns: ['company_id', 'address_id'])]
#[ORM\HasLifecycleCallbacks]
#[Assert\EnableAutoMapping]
class CompanyAddress
{
    use IdentifiableIntNonNullable;
    use MetaTrait;
    use TimestampableCreatedAndUpdated;
    use TimestampableDeletedNullable;

    final public const string TYPE_HEADQUARTERS = 'headquarters';  // Sediu social
    final public const string TYPE_BRANCH       = 'branch';        // Punct de lucru
    final public const string TYPE_WAREHOUSE    = 'warehouse';     // Depozit
    final public const string TYPE_OFFICE       = 'office';        // Birou
    final public const string TYPE_OTHER        = 'other';         // Altele

    #[ORM\ManyToOne(targetEntity: Company::class, inversedBy: 'companyAddresses')]
    #[ORM\JoinColumn(name: 'company_id', referencedColumnName: 'id', nullable: false, onDelete: 'CASCADE')]
    private Company $company;

    #[ORM\ManyToOne(targetEntity: Address::class)]
    #[ORM\JoinColumn(name: 'address_id', referencedColumnName: 'id', nullable: false, onDelete: 'RESTRICT')]
    private Address $address;

    #[ORM\Column(name: 'type', type: Types::STRING, length: 50, nullable: false)]
    #[Assert\NotBlank]
    #[Assert\Choice(callback: 'getAvailableTypes')]
    private string $type = self::TYPE_HEADQUARTERS;

    #[ORM\Column(name: 'is_primary', type: Types::BOOLEAN, nullable: false, options: ['default' => false])]
    private bool $isPrimary = false;

    #[ORM\Column(name: 'label', type: Types::STRING, length: 255, nullable: true, options: ['comment' => 'Custom label for this address'])]
    private ?string $label = null;

    ###################################################################################################################################################################################################
    ###   Custom methods   ############################################################################################################################################################################

    public function __toString(): string
    {
        return $this->label ?? $this->getTypeLabel();
    }

    public function getSupportedTypes(): array
    {
        $reflection = new \ReflectionClass($this);
        return array_filter($reflection->getConstants(), function ($constantKey) {
            return str_starts_with($constantKey, 'TYPE_');
        }, ARRAY_FILTER_USE_KEY);
    }

    public static function getAvailableTypes(): array
    {
        return array_values(new self()->getSupportedTypes());
    }

    public function getTypeLabel(): string
    {
        return match ($this->type) {
            self::TYPE_HEADQUARTERS => 'Headquarters',
            self::TYPE_BRANCH       => 'Branch',
            self::TYPE_WAREHOUSE    => 'Warehouse',
            self::TYPE_OFFICE       => 'Office',
            self::TYPE_OTHER        => 'Other',
            default                 => $this->type,
        };
    }

    ###################################################################################################################################################################################################
    ###   IDE generated setters & getters   ###########################################################################################################################################################
}

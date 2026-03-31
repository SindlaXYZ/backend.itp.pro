<?php

namespace App\Entity;

use App\Repository\CompanyRepository;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Identifiable\IdentifiableIntNonNullable;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Misc\MetaTrait;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableCreatedAndUpdated;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableCroned;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableDeletedNullable;

#[ORM\Table(name: 'company')]
#[ORM\Entity(repositoryClass: CompanyRepository::class)]
#[ORM\HasLifecycleCallbacks()]
class Company
{
    use IdentifiableIntNonNullable;
    use MetaTrait;
    use TimestampableCreatedAndUpdated;
    use TimestampableCroned;
    use TimestampableDeletedNullable;

    #[ORM\Column(name: 'name', type: Types::STRING, length: 255, nullable: false)]
    private string $name;

    #[ORM\Column(name: 'slug', type: Types::STRING, length: 255, nullable: false)]
    private string $slug;

    #[ORM\Column(name: 'type', type: Types::STRING, length: 255, nullable: false)]
    private string $type;

    #[ORM\ManyToOne(targetEntity: self::class, inversedBy: 'children')]
    #[ORM\JoinColumn(name: 'parent_id', referencedColumnName: 'id', nullable: true, onDelete: 'SET NULL')]
    private ?self $parent = null;

    #[ORM\OneToMany(targetEntity: self::class, mappedBy: 'parent')]
    private Collection $children;

    #[ORM\OneToMany(targetEntity: User::class, mappedBy: 'company')]
    #[ORM\OrderBy(['id' => 'ASC'])]
    private Collection $users;

    #[ORM\OneToMany(targetEntity: CompanyAddress::class, mappedBy: 'company')]
    private Collection $companyAddresses;

    ###################################################################################################################################################################################################
    ###   Custom methods   ############################################################################################################################################################################

    public function __construct()
    {
        $this->children         = new ArrayCollection();
        $this->users            = new ArrayCollection();
        $this->companyAddresses = new ArrayCollection();
    }

    ###################################################################################################################################################################################################
    ###   IDE generated setters & getters   ###########################################################################################################################################################
}

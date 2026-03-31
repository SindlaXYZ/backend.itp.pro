<?php

namespace App\Entity;

use App\Repository\UserRepository;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;
use Sindla\Bundle\AuroraBundle\Doctrine\Attributes\Aurora;
use Sindla\Bundle\AuroraBundle\Doctrine\TypeHint\BitwiseOperator;
use Sindla\Bundle\AuroraBundle\Doctrine\TypeHint\MetaData;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Identifiable\IdentifiableIntNonNullable;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Misc\MetaTrait;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableCreatedAndUpdated;
use Sindla\Bundle\AuroraBundle\Utils\Strink\Strink;
use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;
use Symfony\Component\Security\Core\User\UserInterface;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Table(name: '`user`')]
#[ORM\Entity(repositoryClass: UserRepository::class)]
#[ORM\HasLifecycleCallbacks]
#[Assert\EnableAutoMapping]
class User implements UserInterface, PasswordAuthenticatedUserInterface
{
    use IdentifiableIntNonNullable;
    use MetaTrait;
    use TimestampableCreatedAndUpdated;

    final public const string ROLE_USER        = 'ROLE_USER';
    final public const string ROLE_ADMIN       = 'ROLE_ADMIN';
    final public const string ROLE_SUPER_ADMIN = 'ROLE_SUPER_ADMIN';

    // Bitwise statuses
    final public const int STATUS_INACTIVE        = 1;
    final public const int STATUS_EMAIL_CONFIRMED = 1 << 1;  # has value 2
    final public const int STATUS_SUSPENDED       = 1 << 2;  # has value 4
    final public const int STATUS_DELETED         = 1 << 3;  # has value 8

    #[ORM\ManyToOne(targetEntity: Company::class, inversedBy: 'users')]
    #[ORM\JoinColumn(name: 'company_id', referencedColumnName: 'id', nullable: false, onDelete: 'RESTRICT')]
    private Company $company;

    #[ORM\Column(name: 'first_name', type: Types::STRING, length: 255, nullable: false)]
    private string $firstName;

    #[ORM\Column(name: 'middle_name', type: Types::STRING, length: 255, nullable: true)]
    private ?string $middleName = null;

    #[ORM\Column(name: 'last_name', type: Types::STRING, length: 255, nullable: false)]
    private string $lastName;

    #[ORM\Column(name: 'birthdate', type: Types::DATE_IMMUTABLE, nullable: false)]
    private \DateTimeImmutable $birthdate;

    #[ORM\Column(name: 'username', type: Types::STRING, unique: true, nullable: false)]
    #[Assert\NotBlank]
    #[Assert\Length(min: 3, max: 50)]
    private string $username;

    #[ORM\Column(name: 'email', type: Types::STRING, unique: true, nullable: false)]
    #[Assert\NotBlank]
    #[Assert\Email]
    private string $email;

    #[ORM\Column(name: 'password', type: Types::STRING, nullable: true)]
    private ?string $password = null;

    #[ORM\Column(name: 'status', type: Types::INTEGER, nullable: false, options: ['unsigned' => false, 'default' => 1, 'comment' => 'Bitwise status'])]
    #[Aurora(bitwiseConst: 'STATUS_')]
    private int|BitwiseOperator $status = self::STATUS_INACTIVE;

    #[ORM\Column(name: 'roles', type: Types::JSON)]
    #[Assert\Choice(callback: 'getAvailableRoles', multiple: true)]
    private array|MetaData $roles = [];

    #[ORM\OneToMany(targetEntity: Phone::class, mappedBy: 'user')]
    #[ORM\OrderBy(['id' => 'ASC'])]
    private Collection $phones;

    ###################################################################################################################################################################################################
    ###   Custom methods   ############################################################################################################################################################################

    public function __construct()
    {
        $this->phones = new ArrayCollection();
    }

    public function __toString()
    {
        if (method_exists(self::class, 'getFirstName') && method_exists(self::class, 'getLastName')) {
            return new Strink("{$this->getFirstName()} {$this->getLastName()}")->trim()->__toString();
        } else {
            return new Strink("$this->firstName $this->lastName")->trim()->__toString();
        }
    }

    public function getUserIdentifier(): string
    {
        return $this->username;
    }

    public function getPassword(): ?string
    {
        return $this->password;
    }

    public function getRoles(): array
    {
        return $this->roles;
    }

    /**
     * Method is only meant to clean up possibly stored plain text passwords (or similar credentials)
     */
    public function eraseCredentials(): void
    {
    }

    public function __serialize(): array
    {
        return [$this->id, $this->username, $this->password];
    }

    public function __unserialize(array $data): void
    {
        [$this->id, $this->username, $this->password] = $data;
    }

    public function getSupportedRoles(): array
    {
        $reflection = new \ReflectionClass($this);
        return array_filter($reflection->getConstants(), function ($constantKey) {
            return str_starts_with($constantKey, 'ROLE_');
        }, ARRAY_FILTER_USE_KEY);
    }

    public static function getAvailableRoles(): array
    {
        return array_values(new self()->getSupportedRoles());
    }

    ###################################################################################################################################################################################################
    ###   IDE generated setters & getters   ###########################################################################################################################################################
}

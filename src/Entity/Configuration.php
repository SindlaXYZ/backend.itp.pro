<?php

namespace App\Entity;

use App\Repository\ConfigurationRepository;
use App\Service\Entity\ConfigurationService;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;
use Sindla\Bundle\AuroraBundle\Doctrine\Attributes\Aurora;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Identifiable\IdentifiableIntNonNullable;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Misc\MetaTrait;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableCreatedAndUpdated;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * @see ConfigurationService
 */
#[ORM\Table(
    name   : 'configuration',
    options: [
        'comment' => 'Application configuration'
    ]
)]
#[ORM\Entity(repositoryClass: ConfigurationRepository::class)]
#[ORM\UniqueConstraint(name: 'UNIQ_configuration', columns: ['key'])]
#[ORM\HasLifecycleCallbacks]
#[Assert\EnableAutoMapping]
class Configuration
{
    use IdentifiableIntNonNullable;
    use MetaTrait;
    use TimestampableCreatedAndUpdated;

    public final const string TYPE_STRING  = Types::STRING;
    public final const string TYPE_INTEGER = Types::INTEGER;
    public final const string TYPE_BOOLEAN = Types::BOOLEAN;
    public final const string TYPE_ARRAY   = Types::JSON;

    #[ORM\Column(name: 'key', type: Types::STRING, length: 255, nullable: false)]
    private string $key;

    #[ORM\Column(name: 'value', type: Types::STRING, length: 255, nullable: true)]
    private string|int|float|null $value = null;

    #[ORM\Column(name: 'encrypted', type: Types::BOOLEAN, nullable: false, options: ['default' => false])]
    private bool $encrypted = false;

    #[ORM\Column(name: 'type', type: Types::STRING, length: 255, nullable: false)]
    private string $type = self::TYPE_STRING;

    #[ORM\Column(name: 'allowed_values', type: Types::JSON, nullable: false, options: ['default' => '[]'])]
    #[Aurora(json: true)]
    private array $allowedValues = [];

    #[ORM\Column(name: 'description', type: Types::STRING, length: 255, nullable: true)]
    private ?string $description = null;

    ###################################################################################################################################################################################################
    ###   Custom methods   ############################################################################################################################################################################

    public function __construct()
    {
    }

    public function getSupportedTypes(): array
    {
        $reflection = new \ReflectionClass($this);
        return array_filter($reflection->getConstants(), function ($constantKey) {
            return str_starts_with($constantKey, 'TYPE_');
        }, ARRAY_FILTER_USE_KEY);
    }

    ###################################################################################################################################################################################################
    ###   IDE generated setters & getters   ###########################################################################################################################################################

    public function getKey(): string
    {
        return $this->key;
    }

    public function setKey(string $key): self
    {
        $this->key = $key;
        return $this;
    }

    public function getValue(): mixed
    {
        return $this->value;
    }

    public function setValue(mixed $value): self
    {
        $this->value = $value;
        return $this;
    }

    public function isEncrypted(): bool
    {
        return $this->encrypted;
    }

    public function setEncrypted(bool $encrypted): self
    {
        $this->encrypted = $encrypted;
        return $this;
    }

    public function getType(): string
    {
        return $this->type;
    }

    public function setType(string $type): self
    {
        $this->type = $type;
        return $this;
    }

    public function getAllowedValues(): array
    {
        return $this->allowedValues;
    }

    public function setAllowedValues(array $allowedValues): self
    {
        $this->allowedValues = $allowedValues;
        return $this;
    }

    public function addAllowedValue(mixed $allowedValue): self
    {
        $this->allowedValues[] = $allowedValue;
        return $this;
    }

    public function mergeAllowedValues(array $allowedValues): self
    {
        $this->allowedValues = array_merge($this->allowedValues, $allowedValues);
        return $this;
    }

    public function removeAllowedValue(mixed $allowedValue): self
    {
        if (true === in_array($allowedValue, $this->allowedValues, true)) {
            $index = array_search($allowedValue, $this->allowedValues, true);
            array_splice($this->allowedValues, $index, 1);
        }
        return $this;
    }

    public function getDescription(): ?string
    {
        return $this->description;
    }

    public function setDescription(?string $description): self
    {
        $this->description = $description;
        return $this;
    }
}

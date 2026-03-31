<?php

namespace App\Entity;

use App\Repository\CountryRepository;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;
use Sindla\Bundle\AuroraBundle\Doctrine\Attributes\Aurora;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Identifiable\IdentifiableIntNonNullable;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Misc\MetaTrait;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableCreatedAndUpdated;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableDeletedNullable;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableSynchronized;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Table(name: 'country')]
#[ORM\Entity(repositoryClass: CountryRepository::class)]
#[ORM\UniqueConstraint(name: 'UNIQ_country_name', columns: ['name'])]
#[ORM\UniqueConstraint(name: 'UNIQ_country_slug', columns: ['slug'])]
#[ORM\HasLifecycleCallbacks]
#[Assert\EnableAutoMapping]
class Country
{
    use IdentifiableIntNonNullable;
    use MetaTrait;
    use TimestampableCreatedAndUpdated;
    use TimestampableSynchronized;
    use TimestampableDeletedNullable;

    #[ORM\Column(name: 'name', type: Types::STRING, length: 255, nullable: false)]
    #[Assert\NotBlank]
    private string $name;

    #[ORM\Column(name: 'slug', type: Types::STRING, length: 255, nullable: false)]
    #[Assert\NotBlank]
    private string $slug;

    #[ORM\Column(name: 'alpha2code', type: Types::STRING, length: 2, nullable: false, options: ['comment' => 'ISO 3166-1 alpha-2'])]
    #[Assert\NotBlank]
    #[Assert\Length(max: 2)]
    private string $alpha2Code;

    #[ORM\Column(name: 'alpha3code', type: Types::STRING, length: 3, nullable: false, options: ['comment' => 'ISO 3166-1 alpha-3'])]
    #[Assert\NotBlank]
    #[Assert\Length(max: 3)]
    private string $alpha3Code;

    #[ORM\Column(name: 'alpha3numeric', type: Types::STRING, length: 3, nullable: true, options: ['comment' => 'ISO 3166-1 numeric code (UN M49)'])]
    #[Assert\Length(max: 3)]
    private ?string $alpha3Numeric = null;

    #[ORM\Column(name: 'time_zones', type: Types::JSON, nullable: false, options: ['default' => '[]'])]
    #[Aurora(json: true)]
    private array $timeZones = [];

    #[ORM\Column(name: 'e164_country_code', type: Types::SMALLINT, nullable: false, options: ['comment' => 'E.164 country code. See https://www.twilio.com/docs/glossary/what-e164 & https://en.wikipedia.org/wiki/List_of_telephone_country_codes'])]
    private int $e164CountryCode;

    #[ORM\Column(name: 'e164_national_trunk_prefix', type: Types::SMALLINT, nullable: false, options: ['comment' => 'See https://en.wikipedia.org/wiki/List_of_telephone_country_codes'])]
    private int $e164NationalTrunkPrefix;

    #[ORM\Column(name: 'top_level_domain', type: Types::STRING, length: 5, nullable: true)]
    private ?string $topLevelDomain = null;

    #[ORM\OneToMany(targetEntity: County::class, mappedBy: 'country')]
    #[ORM\OrderBy(['name' => 'ASC'])]
    private Collection $counties;

    ###################################################################################################################################################################################################
    ###   Custom methods   ############################################################################################################################################################################

    public function __construct()
    {
        $this->counties = new ArrayCollection();
    }

    public function __toString(): string
    {
        return $this->name;
    }

    ###################################################################################################################################################################################################
    ###   IDE generated setters & getters   ###########################################################################################################################################################

    public function getName(): string
    {
        return $this->name;
    }

    public function setName(string $name): self
    {
        $this->name = $name;
        return $this;
    }

    public function getSlug(): string
    {
        return $this->slug;
    }

    public function setSlug(string $slug): self
    {
        $this->slug = $slug;
        return $this;
    }

    public function getAlpha2Code(): string
    {
        return $this->alpha2Code;
    }

    public function setAlpha2Code(string $alpha2Code): self
    {
        $this->alpha2Code = $alpha2Code;
        return $this;
    }

    public function getAlpha3Code(): string
    {
        return $this->alpha3Code;
    }

    public function setAlpha3Code(string $alpha3Code): self
    {
        $this->alpha3Code = $alpha3Code;
        return $this;
    }

    public function getAlpha3Numeric(): ?string
    {
        return $this->alpha3Numeric;
    }

    public function setAlpha3Numeric(?string $alpha3Numeric): self
    {
        $this->alpha3Numeric = $alpha3Numeric;
        return $this;
    }

    public function getTimeZones(): array
    {
        return $this->timeZones;
    }

    public function setTimeZones(array $timeZones): self
    {
        $this->timeZones = $timeZones;
        return $this;
    }

    public function addTimeZone(mixed $timeZone): self
    {
        $this->timeZones[] = $timeZone;
        return $this;
    }

    public function mergeTimeZones(array $timeZones): self
    {
        $this->timeZones = (is_array($this->timeZones) ? array_merge($this->timeZones, $timeZones) : $timeZones);
        return $this;
    }

    public function removeTimeZone(mixed $timeZone): self
    {
        if (true === in_array($timeZone, $this->timeZones, true)) {
            $index = array_search($timeZone, $this->timeZones);
            array_splice($this->timeZones, $index, 1);
        }
        return $this;
    }

    public function getE164CountryCode(): int
    {
        return $this->e164CountryCode;
    }

    public function setE164CountryCode(int $e164CountryCode): self
    {
        $this->e164CountryCode = $e164CountryCode;
        return $this;
    }

    public function getE164NationalTrunkPrefix(): int
    {
        return $this->e164NationalTrunkPrefix;
    }

    public function setE164NationalTrunkPrefix(int $e164NationalTrunkPrefix): self
    {
        $this->e164NationalTrunkPrefix = $e164NationalTrunkPrefix;
        return $this;
    }

    public function getTopLevelDomain(): ?string
    {
        return $this->topLevelDomain;
    }

    public function setTopLevelDomain(?string $topLevelDomain): self
    {
        $this->topLevelDomain = $topLevelDomain;
        return $this;
    }

    public function getCounties(): Collection
    {
        return $this->counties;
    }

    public function setCounties(Collection $counties): self
    {
        $this->counties = $counties;
        return $this;
    }

    public function addCountie(County $countie): self
    {
        if (!$this->counties->contains($countie)) {
            $this->counties->add($countie);
            if (method_exists($countie, 'setCountry')) {
                $countie->setCountry($this);
            }
        }
        return $this;
    }

    public function removeCountie(County $countie): self
    {
        if ($this->counties->contains($countie)) {
            if ($this->counties->removeElement($countie)) {
                // set the owning side to null (unless already changed)
                if (method_exists($countie, 'getCountry') && method_exists($countie, 'setCountry') && new \ReflectionClass($countie)->getMethod('setCountry')->getParameters()[0]->allowsNull() && $countie->getCountry() === $this) {
                    $countie->setCountry(null);
                }
            }
        }
        return $this;
    }
}

<?php

namespace App\Entity;

use App\Repository\CountyRepository;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Identifiable\IdentifiableIntNonNullable;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Identifiable\LegacyIntNullable;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Misc\MetaTrait;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableCreatedAndUpdated;
use Sindla\Bundle\AuroraBundle\Entity\SuperAttribute\Timestampable\TimestampableDeletedNullable;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Table(name: 'county')]
#[ORM\Entity(repositoryClass: CountyRepository::class)]
#[ORM\UniqueConstraint(name: 'UNIQ_county_country_id_name', columns: ['country_id', 'name'])]
#[ORM\HasLifecycleCallbacks]
#[Assert\EnableAutoMapping]
class County
{
    use IdentifiableIntNonNullable;
    use LegacyIntNullable;
    use MetaTrait;
    use TimestampableCreatedAndUpdated;
    use TimestampableDeletedNullable;

    #[ORM\ManyToOne(targetEntity: Country::class, inversedBy: 'counties')]
    #[ORM\JoinColumn(name: 'country_id', referencedColumnName: 'id', nullable: false, onDelete: 'RESTRICT')]
    private Country $country;

    #[ORM\Column(name: 'name', type: Types::STRING, length: 255, nullable: false)]
    #[Assert\NotBlank]
    private string $name;

    #[ORM\Column(name: 'slug', type: Types::STRING, length: 255, nullable: false)]
    #[Assert\NotBlank]
    private string $slug;

    #[ORM\Column(name: 'code', type: Types::STRING, length: 10, nullable: true, options: ['comment' => 'County code (e.g., B for Bucharest, CJ for Cluj)'])]
    private ?string $code = null;

    #[ORM\OneToMany(targetEntity: City::class, mappedBy: 'county')]
    #[ORM\OrderBy(['name' => 'ASC'])]
    private Collection $cities;

    ###################################################################################################################################################################################################
    ###   Custom methods   ############################################################################################################################################################################

    public function __construct()
    {
        $this->cities = new ArrayCollection();
    }

    public function __toString(): string
    {
        return $this->name;
    }

    ###################################################################################################################################################################################################
    ###   IDE generated setters & getters   ###########################################################################################################################################################

    public function getCountry(): Country
    {
        return $this->country;
    }

    public function setCountry(Country $country): self
    {
        $this->country = $country;
        return $this;
    }

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

    public function getCode(): ?string
    {
        return $this->code;
    }

    public function setCode(?string $code): self
    {
        $this->code = $code;
        return $this;
    }

    public function getCities(): Collection
    {
        return $this->cities;
    }

    public function setCities(Collection $cities): self
    {
        $this->cities = $cities;
        return $this;
    }

    public function addCity(City $city): self
    {
        if (!$this->cities->contains($city)) {
            $this->cities->add($city);
            if (method_exists($city, 'setCounty')) {
                $city->setCounty($this);
            }
        }
        return $this;
    }

    public function removeCity(City $city): self
    {
        if ($this->cities->contains($city)) {
            if ($this->cities->removeElement($city)) {
                // set the owning side to null (unless already changed)
                if (method_exists($city, 'getCounty') && method_exists($city, 'setCounty') && new \ReflectionClass($city)->getMethod('setCounty')->getParameters()[0]->allowsNull() && $city->getCounty() === $this) {
                    $city->setCounty(null);
                }
            }
        }
        return $this;
    }
}

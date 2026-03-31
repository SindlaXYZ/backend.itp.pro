<?php

namespace App\Entity;

use App\Repository\CityRepository;
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

#[ORM\Table(name: 'city')]
#[ORM\Entity(repositoryClass: CityRepository::class)]
#[ORM\UniqueConstraint(name: 'UNIQ_city_county_id_name', columns: ['county_id', 'name'])]
#[ORM\HasLifecycleCallbacks]
#[Assert\EnableAutoMapping]
class City
{
    use IdentifiableIntNonNullable;
    use LegacyIntNullable;
    use MetaTrait;
    use TimestampableCreatedAndUpdated;
    use TimestampableDeletedNullable;

    #[ORM\ManyToOne(targetEntity: County::class, inversedBy: 'cities')]
    #[ORM\JoinColumn(name: 'county_id', referencedColumnName: 'id', nullable: false, onDelete: 'RESTRICT')]
    private County $county;

    #[ORM\Column(name: 'name', type: Types::STRING, length: 255, nullable: false)]
    #[Assert\NotBlank]
    private string $name;

    #[ORM\Column(name: 'slug', type: Types::STRING, length: 255, nullable: false)]
    #[Assert\NotBlank]
    private string $slug;

    #[ORM\Column(name: 'postal_code', type: Types::STRING, length: 20, nullable: true)]
    private ?string $postalCode = null;

    #[ORM\OneToMany(targetEntity: Address::class, mappedBy: 'city')]
    private Collection $addresses;

    ###################################################################################################################################################################################################
    ###   Custom methods   ############################################################################################################################################################################

    public function __construct()
    {
        $this->addresses = new ArrayCollection();
    }

    public function __toString(): string
    {
        return $this->name;
    }

    ###################################################################################################################################################################################################
    ###   IDE generated setters & getters   ###########################################################################################################################################################

    public function getCounty(): County
    {
        return $this->county;
    }

    public function setCounty(County $county): self
    {
        $this->county = $county;
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

    public function getPostalCode(): ?string
    {
        return $this->postalCode;
    }

    public function setPostalCode(?string $postalCode): self
    {
        $this->postalCode = $postalCode;
        return $this;
    }

    public function getAddresses(): Collection
    {
        return $this->addresses;
    }

    public function setAddresses(Collection $addresses): self
    {
        $this->addresses = $addresses;
        return $this;
    }

    public function addAddress(Address $address): self
    {
        if (!$this->addresses->contains($address)) {
            $this->addresses->add($address);
            if (method_exists($address, 'setCity')) {
                $address->setCity($this);
            }
        }
        return $this;
    }

    public function removeAddress(Address $address): self
    {
        if ($this->addresses->contains($address)) {
            if ($this->addresses->removeElement($address)) {
                // set the owning side to null (unless already changed)
                if (method_exists($address, 'getCity') && method_exists($address, 'setCity') && new \ReflectionClass($address)->getMethod('setCity')->getParameters()[0]->allowsNull() && $address->getCity() === $this) {
                    $address->setCity(null);
                }
            }
        }
        return $this;
    }
}

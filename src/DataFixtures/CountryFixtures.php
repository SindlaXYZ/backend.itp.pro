<?php

namespace App\DataFixtures;

use App\DataFixtures\Middleware\DataFixturesMiddleware;
use App\Entity\Country;
use Doctrine\Bundle\FixturesBundle\FixtureGroupInterface;
use Doctrine\Persistence\ObjectManager;
use Symfony\Component\Serializer\Normalizer\AbstractNormalizer;
use Symfony\Component\Serializer\SerializerInterface;

/**
 * php bin/console doctrine:fixtures:load -v --append --group=CountryFixtures
 */
class CountryFixtures extends DataFixturesMiddleware implements FixtureGroupInterface
{
    public function __construct(
        private readonly SerializerInterface $serializer
    )
    {
    }

    public static function getGroups(): array
    {
        return parent::getAllGroups();
    }

    /**
     * @throws \Exception
     */
    public function load(ObjectManager $manager): void
    {
        $countries = $this->readYamlFile(dirname(__FILE__) . '/CountryFixtures.yaml');

        foreach ($countries as $countryArray) {
            /** @var Country $country */
            $country = $this->serializer->denormalize($countryArray, Country::class);

            if ($existingCountry = $manager->getRepository(Country::class)->findOneBy(['alpha2Code' => $country->getAlpha2Code()])) {
                $country = $this->serializer->denormalize($countryArray, Country::class, null, [
                    AbstractNormalizer::OBJECT_TO_POPULATE => $existingCountry
                ]);
            }

            $manager->persist($country);
        }

        $manager->flush();
    }
}

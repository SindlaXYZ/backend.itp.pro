<?php

namespace App\DataFixtures;

use App\DataFixtures\Middleware\DataFixturesMiddleware;
use App\Entity\City;
use App\Entity\Country;
use App\Entity\County;
use Doctrine\Bundle\FixturesBundle\FixtureGroupInterface;
use Doctrine\Common\DataFixtures\DependentFixtureInterface;
use Doctrine\Persistence\ObjectManager;
use Symfony\Component\String\Slugger\AsciiSlugger;

/**
 * php bin/console doctrine:fixtures:load -v --append --group=CityFixtures
 */
class CityFixtures extends DataFixturesMiddleware implements FixtureGroupInterface, DependentFixtureInterface
{
    public function __construct()
    {
    }

    public static function getGroups(): array
    {
        return ['CityFixtures'];
    }

    public function getDependencies(): array
    {
        return [
            CountyFixtures::class
        ];
    }

    /**
     * @throws \Exception
     */
    public function load(ObjectManager $manager): void
    {
        // https://geo-spatial.org/vechi/download/romania-seturi-vectoriale > Limitele unităților administrative din România > Limite UAT poligon > TopoJSON
        $citiesJson     = $this->readFile(dirname(__FILE__) . '/data/ro_uat_poligon.topojson');
        $citiesArrays   = json_decode($citiesJson, true);
        $countryRomania = $manager->getRepository(Country::class)->findOneBy(['alpha2Code' => 'RO']);

        foreach ($citiesArrays['objects']['ro_uat_poligon']['geometries'] ?? [] as $geometries) {
            $cityArray          = $geometries['properties'];
            $cityCountyLegacyId = $cityArray['countyId'];
            $cityLegacyId       = $cityArray['natcode']; // SIRUTE
            $cityName           = $cityArray['name'];
            $cityCountyName     = $cityArray['county'];

            if (!$county = $manager->getRepository(County::class)->findOneBy(['legacyId' => $cityCountyLegacyId])) {
                throw new \Exception(sprintf('County with legacy ID `%s` not found for City `%s` (`%s`)', $cityCountyLegacyId, $cityName, $cityCountyName));
            }

            /** @var City $city */
            if (!$city = $manager->getRepository(City::class)->findOneBy(['legacyId' => $cityLegacyId])) {
                $city = new City();
            }

            $city
                ->setLegacyId($cityLegacyId)
                ->setCounty($county)
                ->setName($cityName)
                ->setSlug(new AsciiSlugger()->slug($cityName)->lower())
                ->setMeta($cityArray);

            $manager->persist($city);
        }

        $manager->flush();
    }
}

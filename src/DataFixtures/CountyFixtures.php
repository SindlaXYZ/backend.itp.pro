<?php

namespace App\DataFixtures;

use App\DataFixtures\Middleware\DataFixturesMiddleware;
use App\Entity\Country;
use App\Entity\County;
use Doctrine\Bundle\FixturesBundle\FixtureGroupInterface;
use Doctrine\Common\DataFixtures\DependentFixtureInterface;
use Doctrine\Persistence\ObjectManager;
use Symfony\Component\String\Slugger\AsciiSlugger;

/**
 * php bin/console doctrine:fixtures:load -v --append --group=CountyFixtures
 */
class CountyFixtures extends DataFixturesMiddleware implements FixtureGroupInterface, DependentFixtureInterface
{
    public function __construct()
    {
    }

    public static function getGroups(): array
    {
        return parent::getAllGroups();
    }

    public function getDependencies(): array
    {
        return [
            CountryFixtures::class
        ];
    }

    /**
     * @throws \Exception
     */
    public function load(ObjectManager $manager): void
    {
        // https://geo-spatial.org/vechi/download/romania-seturi-vectoriale > Limitele județelor din România > Limite județe poligon > TopoJSON
        $countiesJson   = $this->readFile(dirname(__FILE__) . '/data/ro_judete_poligon.topojson');
        $countiesArrays = json_decode($countiesJson, true);
        $countryRomania = $manager->getRepository(Country::class)->findOneBy(['alpha2Code' => 'RO']);

        foreach ($countiesArrays['objects']['ro_judete_poligon']['geometries'] ?? [] as $geometries) {
            $countiesArray   = $geometries['properties'];
            $countryLegacyId = $countiesArray['countyId'];
            $countyName      = $countiesArray['name'];
            $countyCode      = $countiesArray['mnemonic'];

            /** @var County $county */
            if (!$county = $manager->getRepository(County::class)->findOneBy(['code' => $countyCode])) {
                $county = new County();
            }

            $county
                ->setLegacyId($countryLegacyId)
                ->setName($countyName)
                ->setSlug(new AsciiSlugger()->slug($countyName)->lower())
                ->setCode($countyCode)
                ->setMeta($countiesArray)
                ->setCountry($countryRomania);

            $manager->persist($county);
        }

        $manager->flush();
    }
}

<?php

namespace App\DataFixtures;

use App\DataFixtures\Middleware\DataFixturesMiddleware;
use App\Entity\Configuration;
use Doctrine\Bundle\FixturesBundle\FixtureGroupInterface;
use Doctrine\Persistence\ObjectManager;

/**
 * php bin/console doctrine:fixtures:load -v --append --group=ConfigurationFixtures
 */
class ConfigurationFixtures extends DataFixturesMiddleware implements FixtureGroupInterface
{
    public function __construct()
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
        $configurations = $this->readYamlFile(dirname(__FILE__) . '/ConfigurationFixtures.yaml');

        foreach ($configurations as $configurationArray) {
            if (!$configuration = $manager->getRepository(Configuration::class)->findOneBy(['key' => $configurationArray['key']])) {
                $configuration = new Configuration();
            }

            $configuration
                ->setKey($configurationArray['key'])
                ->setType($configurationArray['type'])
                ->setEncrypted($configurationArray['encrypted'] ?? false)
                ->setDescription($configurationArray['description'] ?? null);

            $manager->persist($configuration);
            $manager->flush();
        }
    }
}

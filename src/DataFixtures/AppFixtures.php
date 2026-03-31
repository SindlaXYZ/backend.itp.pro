<?php

namespace App\DataFixtures;

use App\DataFixtures\Middleware\DataFixturesMiddleware;
use Doctrine\Bundle\FixturesBundle\FixtureGroupInterface;
use Doctrine\Common\DataFixtures\DependentFixtureInterface;
use Doctrine\Persistence\ObjectManager;
use Symfony\Component\DependencyInjection\ParameterBag\ParameterBagInterface;

/**
 * php bin/console doctrine:fixtures:load -v --append --group=AppFixtures
 */
class AppFixtures extends DataFixturesMiddleware implements FixtureGroupInterface, DependentFixtureInterface
{
    public function __construct(
        private readonly ParameterBagInterface $parameterBag
    )
    {
    }

    public static function getGroups(): array
    {
        return parent::getAllGroups();
    }

    public function getDependencies(): array
    {
        return [
            ConfigurationFixtures::class
        ];
    }

    /**
     * @throws \Exception
     */
    public function load(ObjectManager $manager): void
    {
        // $product = new Product();
        // $manager->persist($product);
        // $manager->flush();
    }
}

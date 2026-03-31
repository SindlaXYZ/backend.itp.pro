<?php

namespace App\Repository;

use App\Entity\City;
use App\Repository\Traits\Repository;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

class CityRepository extends ServiceEntityRepository
{
    use Repository;

    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, City::class);
    }
}

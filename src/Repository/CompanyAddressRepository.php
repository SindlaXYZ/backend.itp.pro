<?php

namespace App\Repository;

use App\Entity\CompanyAddress;
use App\Repository\Traits\Repository;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

class CompanyAddressRepository extends ServiceEntityRepository
{
    use Repository;

    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, CompanyAddress::class);
    }
}

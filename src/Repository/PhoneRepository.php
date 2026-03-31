<?php

namespace App\Repository;

use App\Entity\Phone;
use App\Repository\Traits\Repository;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

class PhoneRepository extends ServiceEntityRepository
{
    use Repository;

    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Phone::class);
    }
}

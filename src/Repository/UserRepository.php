<?php

namespace App\Repository;

use App\Entity\User;
use App\Repository\Traits\Repository;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;
use Sindla\Bundle\AuroraBundle\Repository\Traits\BaseRepository;

class UserRepository extends ServiceEntityRepository
{
    use Repository;
    use BaseRepository;

    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, User::class);
    }
}

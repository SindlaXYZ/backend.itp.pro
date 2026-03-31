<?php

namespace App\Repository;

use App\Entity\ThirdPartyRequest;
use App\Repository\Traits\Repository;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

class ThirdPartyRequestRepository extends ServiceEntityRepository
{
    use Repository;

    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, ThirdPartyRequest::class);
    }

    /**
     * @throws \DateMalformedStringException
     */
    public function getCached(ThirdPartyRequest $thirdPartyRequest): ?ThirdPartyRequest
    {
        /** @var ThirdPartyRequest $cachedThirdPartyRequest */
        $cachedThirdPartyRequest = $this->createQueryBuilder('thirdPartyRequest')
            ->where('thirdPartyRequest.hash = :hash')->setParameter('hash', $thirdPartyRequest->getHash())
            ->andWhere('thirdPartyRequest.status = :status')->setParameter('status', ThirdPartyRequest::STATUS_SUCCESS)
            ->andWhere('thirdPartyRequest.responseContentType IS NOT NULL')
            ->andWhere('thirdPartyRequest.respondedAt IS NOT NULL')
            ->orderBy('thirdPartyRequest.respondedAt', self::DESC)
            ->addOrderBy('thirdPartyRequest.id', self::DESC)
            ->setMaxResults(1)
            ->getQuery()
            ->getOneOrNullResult();

        if ($cachedThirdPartyRequest && !$cachedThirdPartyRequest->isExpired()) {
            return $cachedThirdPartyRequest;
        }

        return null;
    }

    public function getSuccessByThirdPartyAndIdentifierKeyAndCreatedAtAfter(
        string             $thirdParty,
        string             $identifierKey,
        \DateTimeImmutable $createdAtAfter,
        string             $order = self::DESC,
        ?int               $limit = null
    ): array
    {
        return $this->createQueryBuilder('thirdPartyRequest')
            ->where('thirdPartyRequest.thirdParty = :thirdParty')->setParameter('thirdParty', $thirdParty)
            ->andWhere('thirdPartyRequest.identifierKey = :identifierKey')->setParameter('identifierKey', $identifierKey)
            ->andWhere('thirdPartyRequest.status = :status')->setParameter('status', ThirdPartyRequest::STATUS_SUCCESS)
            ->andWhere('thirdPartyRequest.responseContentType IS NOT NULL')
            ->andWhere('thirdPartyRequest.createdAt >= :createdAt')->setParameter('createdAt', $createdAtAfter)
            ->orderBy('thirdPartyRequest.id', $order)
            ->setMaxResults($limit)
            ->getQuery()
            ->getResult();
    }

    public function getSuccessByThirdPartyAndIdentifierKeyAndValueAndCreatedAtAfter(
        string             $thirdParty,
        string             $identifierKey,
        int|string         $identifierValue,
        \DateTimeImmutable $createdAtAfter,
        string             $order = self::DESC,
        ?int               $limit = null
    ): array
    {
        return $this->createQueryBuilder('thirdPartyRequest')
            ->where('thirdPartyRequest.thirdParty = :thirdParty')->setParameter('thirdParty', $thirdParty)
            ->andWhere('thirdPartyRequest.identifierKey = :identifierKey')->setParameter('identifierKey', $identifierKey)
            ->andWhere('thirdPartyRequest.identifierValue = :identifierValue')->setParameter('identifierValue', $identifierValue)
            ->andWhere('thirdPartyRequest.status = :status')->setParameter('status', ThirdPartyRequest::STATUS_SUCCESS)
            ->andWhere('thirdPartyRequest.responseContentType IS NOT NULL')
            ->andWhere('thirdPartyRequest.createdAt >= :createdAt')->setParameter('createdAt', $createdAtAfter)
            ->orderBy('thirdPartyRequest.id', $order)
            ->setMaxResults($limit)
            ->getQuery()
            ->getResult();
    }

    public function getSuccessByThirdPartyAndTime(
        string $thirdParty,
        string $identifierKey,
        int    $seconds,
        string $orderBy = 'id',
        string $order = self::DESC,
        ?int   $limit = null
    ): ?ThirdPartyRequest
    {
        return $this->createQueryBuilder('thirdPartyRequest')
            ->where('thirdPartyRequest.thirdParty = :thirdParty')->setParameter('thirdParty', $thirdParty)
            ->andWhere('thirdPartyRequest.identifierKey = :identifierKey')->setParameter('identifierKey', $identifierKey)
            ->andWhere('thirdPartyRequest.status = :status')->setParameter('status', ThirdPartyRequest::STATUS_SUCCESS)
            ->andWhere('thirdPartyRequest.responseContentType IS NOT NULL')
            ->andWhere('thirdPartyRequest.createdAt > :createdAt')->setParameter('createdAt', new \DateTimeImmutable(sprintf('-%d seconds', $seconds)))
            ->orderBy('thirdPartyRequest.' . $orderBy, $order)
            ->setMaxResults($limit)
            ->getQuery()
            ->getOneOrNullResult();
    }

    /**
     * @throws \DateMalformedStringException
     */
    public function getFailedByThirdPartyAndTime(
        string $thirdParty,
        string $endpointName,
        int    $seconds,
        string $order = self::DESC,
        ?int   $limit = null
    ): array
    {
        return $this->createQueryBuilder('thirdPartyRequest')
            ->where('thirdPartyRequest.thirdParty = :thirdParty')->setParameter('thirdParty', $thirdParty)
            ->andWhere('thirdPartyRequest.endpointName = :endpointName')->setParameter('endpointName', $endpointName)
            ->andWhere('thirdPartyRequest.status = :status')->setParameter('status', ThirdPartyRequest::STATUS_FAILED)
            ->andWhere('thirdPartyRequest.createdAt > :createdAt')->setParameter('createdAt', new \DateTimeImmutable(sprintf('-%d seconds', $seconds)))
            ->orderBy('thirdPartyRequest.id', $order)
            ->setMaxResults($limit)
            ->getQuery()
            ->getResult();
    }
}

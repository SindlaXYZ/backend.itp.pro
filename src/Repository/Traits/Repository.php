<?php

namespace App\Repository\Traits;

use Doctrine\Common\Collections\Order;
use Doctrine\ORM\NonUniqueResultException;
use Doctrine\ORM\NoResultException;
use Doctrine\ORM\Query;
use Doctrine\ORM\Query\ResultSetMapping;
use Sindla\Bundle\AuroraBundle\Doctrine\DQL\SortableNullsWalker;
use Sindla\Bundle\AuroraBundle\Utils\Strink\Strink;

trait Repository
{
    protected string $rootEntity = '';

    final public const string ASC  = Order::Ascending->value;
    final public const string DESC = Order::Descending->value;

    public function getEntityShortName(): string
    {
        $array = explode('\\', $this->getClassName());
        return end($array);
    }

    /**
     * @throws NonUniqueResultException
     * @throws NoResultException
     * @throws \Exception
     */
    public function tableIsEmpty(): bool
    {
        return (0 == $this->getEntityManager()
                ->createQueryBuilder()
                ->select(sprintf('count(%s.id)', "{$this->getTableName()}_alias"))
                ->from($this->getClassName(), "{$this->getTableName()}_alias")
                ->getQuery()
                ->getSingleScalarResult());
    }

    public function softRemove(object $entity): object
    {
        $entity->setDeletedAt(new \DateTimeImmutable());
        $this->getEntityManager()->persist($entity);
        $this->getEntityManager()->flush();
        return $entity;
    }

    public function save(object $entity): object
    {
        $this->getEntityManager()->persist($entity);
        $this->getEntityManager()->flush();
        return $entity;
    }

    public function deleteAll(): void
    {
        $this->getEntityManager()->createQuery(sprintf('DELETE FROM "%s"', $this->getClassName()))->execute();
    }

    public function getByUpdatedAt(int $maxResults = 0, int $firstResult = 0)
    {
        $alias = "{$this->getTableName()}_alias";

        $qb = $this->getEntityManager()->createQueryBuilder()
            ->select(sprintf('%s', $alias))
            ->from($this->getClassName(), $alias)
            ->orderBy(sprintf('%s.updatedAt', $alias), 'ASC');

        if ($firstResult > 0) {
            $qb->setFirstResult($firstResult);
        }

        if ($maxResults > 0) {
            $qb->setMaxResults($maxResults);
        }

        $query = $qb->getQuery();
        $query->setHint(Query::HINT_CUSTOM_OUTPUT_WALKER, SortableNullsWalker::class);
        $query->setHint("sortableNulls.fields", [
            sprintf('%s.updatedAt', $alias) => SortableNullsWalker::NULLS_FIRST
        ]);

        return $query->getResult();
    }

    /**
     * @throws \Exception
     */
    private function getTableName(): string
    {
        return new Strink()->string($this->getEntityShortName())->camelCaseToSnakeCase();
    }

    /**
     * @throws \Exception
     *
     * @see CronCommand::deleteOldMonolog()
     *
     */
    public function deleteOlderThan(int $second): void
    {
        if (false) {
            $this->getEntityManager()->getConnection()->executeQuery(
                sprintf(
                    "DELETE FROM %s WHERE created_at <= date_trunc('second', current_timestamp at time zone 'UTC' - interval '%d' second)",
                    $this->getTableName(),
                    $second
                )
            );
            return;
        }

        $this->getEntityManager()
            ->createNativeQuery(
                sprintf(
                    "DELETE FROM %s WHERE created_at <= date_trunc('second', current_timestamp at time zone 'UTC' - interval '%d' second)",
                    $this->getTableName(),
                    $second
                ),
                new ResultSetMapping())
            ->execute();
    }
}

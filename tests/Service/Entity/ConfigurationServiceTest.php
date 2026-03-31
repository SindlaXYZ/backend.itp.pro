<?php

namespace App\Service\Entity;

use App\Entity\Configuration;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

readonly class ConfigurationService
{
    private const string ENCRYPTION_CIPHERING = 'AES-128-CTR';
    private const int    ENCRYPTION_OPTION    = 0;

    public function __construct(
        private EntityManagerInterface                  $em,
        #[Autowire('%env(APP_SECRET)%')] private string $appSecret
    )
    {
    }

    public function create(string $key, string $type, array $allowedValues, string $value, bool $encrypted = false, ?string $description = null, ?array $meta = null): void
    {
        /** @var Configuration $configuration */
        if ($this->em->getRepository(Configuration::class)->findOneBy(['key' => $key])) {
            throw new \Exception('Configuration already exists');
        }

        $configuration = new Configuration()
            ->setKey($key)
            ->setType($type)
            ->setAllowedValues($allowedValues)
            ->setValue($value)
            ->setEncrypted($encrypted)
            ->setDescription($description)
            ->setMeta($meta ?? []);

        if ($encrypted) {
            $this->encrypt($configuration);
        }

        $this->em->persist($configuration);
        $this->em->flush();
    }

    /**
     * @throws \Exception
     */
    public function update(string $key, string $value): void
    {
        /** @var Configuration $configuration */
        if (!($configuration = $this->em->getRepository(Configuration::class)->findOneBy(['key' => $key]))) {
            throw new \Exception(sprintf('Configuration key %s not found', $key));
        }

        $configuration->setValue($value);

        if ($configuration->isEncrypted()) {
            $this->encrypt($configuration);
        }

        $this->em->persist($configuration);
        $this->em->flush();
    }

    /**
     * @throws \Exception
     */
    public function get(string $key): mixed
    {
        /** @var Configuration $configuration */
        if (!($configuration = $this->em->getRepository(Configuration::class)->findOneBy(['key' => $key]))) {
            throw new \Exception(sprintf('Configuration key %s not found', $key));
        }

        if ($configuration->getValue() && $configuration->isEncrypted()) {
            return openssl_decrypt($configuration->getValue(), self::ENCRYPTION_CIPHERING, $this->appSecret, self::ENCRYPTION_OPTION, $this->getIv($key));
        }

        return $configuration->getValue();
    }

    public function encrypt(Configuration $configuration): void
    {
        $configuration->setValue(openssl_encrypt($configuration->getValue(), self::ENCRYPTION_CIPHERING, $this->appSecret, self::ENCRYPTION_OPTION, $this->getIv($configuration->getKey())));
    }

    private function getIv(string $key): string
    {
        return substr(sha1($key, true), 0, 16);
    }
}

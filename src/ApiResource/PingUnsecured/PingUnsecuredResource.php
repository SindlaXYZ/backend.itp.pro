<?php

namespace App\ApiResource\PingUnsecured;

use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Post;
use Symfony\Component\Serializer\Attribute\Groups;
use Symfony\Component\Validator\Constraints as Assert;

#[ApiResource(
    shortName             : 'Ping unsecured',
    operations            : [
        new Post(
            uriTemplate: '/ping/unsecured',
            description: 'Send ping and receive pong response',
            processor  : PingUnsecuredStateProcessor::class
        )
    ],
    normalizationContext  : ['groups' => [self::GROUP_READ]],
    denormalizationContext: ['groups' => [self::GROUP_WRITE]]
)]
class PingUnsecuredResource
{
    final const string GROUP_READ  = __CLASS__ . ':read';
    final const string GROUP_WRITE = __CLASS__ . ':write';

    // Input property (for writing)
    #[Assert\NotBlank(message: 'Ping message cannot be empty', payload: ['code' => '182fa15d-5919-4591-906f-b1f6db337f90'])]
    #[Assert\Choice(choices: ['ping'], message: 'Only "ping" value is allowed', payload: ['code' => '92e44b48-b541-4b49-85c2-f0c6d51e7163'])]
    #[Groups([self::GROUP_WRITE])]
    public string $ping;

    // Output property (for reading)
    #[Groups([self::GROUP_READ])]
    public string $pong = 'pong';

    public function __construct(?string $ping = null, string $pong = 'pong')
    {
        if ($ping !== null) {
            $this->ping = $ping;
        }
        $this->pong = $pong;
    }
}

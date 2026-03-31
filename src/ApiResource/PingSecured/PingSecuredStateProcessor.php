<?php

namespace App\ApiResource\PingSecured;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProcessorInterface;

class PingSecuredStateProcessor implements ProcessorInterface
{
    /**
     * @param PingSecuredResource $data
     */
    public function process(mixed $data, Operation $operation, array $uriVariables = [], array $context = []): PingSecuredResource
    {
        if (!$data instanceof PingSecuredResource) {
            throw new \InvalidArgumentException('Expected PingSecuredResource instance');
        }

        if ($data->ping !== 'ping') {
            throw new \InvalidArgumentException('Expected "ping" message');
        }

        // Return a new resource with the response
        return new PingSecuredResource(
            ping: $data->ping,
            pong: 'pong'
        );
    }
}

<?php

namespace App\ApiResource\PingUnsecured;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProcessorInterface;

class PingUnsecuredStateProcessor implements ProcessorInterface
{
    /**
     * @param PingUnsecuredResource $data
     */
    public function process(mixed $data, Operation $operation, array $uriVariables = [], array $context = []): PingUnsecuredResource
    {
        if (!$data instanceof PingUnsecuredResource) {
            throw new \InvalidArgumentException('Expected PingUnsecuredResource instance');
        }

        if ($data->ping !== 'ping') {
            throw new \InvalidArgumentException('Expected "ping" message');
        }

        // Return a new resource with the response
        return new PingUnsecuredResource(
            ping: $data->ping,
            pong: 'pong'
        );
    }
}

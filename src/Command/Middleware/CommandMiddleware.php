<?php

namespace App\Command\Middleware;

/**
 * Just a middleware to be extended by all commands
 */
abstract class CommandMiddleware extends \Sindla\Bundle\AuroraBundle\Command\Middleware\CommandMiddleware
{
    public function __construct()
    {
        parent::__construct();
    }
}

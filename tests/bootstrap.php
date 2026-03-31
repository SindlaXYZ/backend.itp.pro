<?php

use Symfony\Component\Dotenv\Dotenv;

require dirname(__DIR__) . '/vendor/autoload.php';

if (method_exists(Dotenv::class, 'bootEnv')) {
    new Dotenv()->bootEnv(dirname(__DIR__) . '/.env');
    if (file_exists(($dockerEnv = dirname(__DIR__) . '/.envs/.docker/.env'))) {
        new Dotenv()->overload($dockerEnv);
    } else {
        throw  new RuntimeException('The .env file is missing.');
    }
}

if ($_SERVER['APP_DEBUG']) {
    umask(0000);
}

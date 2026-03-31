<?php

namespace App\Tests\Service;

use App\Service\AppService;
use Sindla\Bundle\AuroraBundle\Tests\WebTestCaseMiddleware;

/**
 * APP_ENV=test /usr/bin/php /srv/${DKZ_DOMAIN}/bin/console doctrine:schema:drop --full-database --force; yes | APP_ENV=test APP_DEBUG=0 /usr/bin/php /srv/${DKZ_DOMAIN}/bin/console doctrine:migrations:migrate | APP_ENV=test /usr/bin/php /srv/${DKZ_DOMAIN}/bin/console doctrine:fixtures:load --verbose --append
 *
 * clear; cd /srv/${DKZ_DOMAIN}/; SYMFONY_DEPRECATIONS_HELPER=         /usr/bin/php bin/phpunit -c phpunit.xml.dist tests/Service/ --no-coverage
 * clear; cd /srv/${DKZ_DOMAIN}/; SYMFONY_DEPRECATIONS_HELPER=         /usr/bin/php bin/phpunit -c phpunit.xml.dist tests/Service/AppServiceTest.php --no-coverage
 * clear; cd /srv/${DKZ_DOMAIN}/; SYMFONY_DEPRECATIONS_HELPER=         /usr/bin/php bin/phpunit -c phpunit.xml.dist tests/Service/AppServiceTest.php --no-coverage --stop-on-failure
 *
 * clear; cd /srv/${DKZ_DOMAIN}/; SYMFONY_DEPRECATIONS_HELPER=disabled /usr/bin/php bin/phpunit -c phpunit.xml.dist tests/Service/ --no-coverage
 * clear; cd /srv/${DKZ_DOMAIN}/; SYMFONY_DEPRECATIONS_HELPER=disabled /usr/bin/php bin/phpunit -c phpunit.xml.dist tests/Service/AppServiceTest.php --no-coverage
 * clear; cd /srv/${DKZ_DOMAIN}/; SYMFONY_DEPRECATIONS_HELPER=disabled /usr/bin/php bin/phpunit -c phpunit.xml.dist tests/Service/AppServiceTest.php --no-coverage --stop-on-failure
 */
class AppServiceTest extends WebTestCaseMiddleware
{
    /**
     * clear; cd /srv/${DKZ_DOMAIN}/; /usr/bin/php bin/phpunit -c phpunit.xml.dist tests/Service/AppServiceTest.php --filter testLoggerInfo --no-coverage
     */
    // clear; cd /srv/${DKZ_DOMAIN}/; /usr/bin/php bin/phpunit -c phpunit.xml.dist tests/Service/AppServiceTest.php --no-coverage --do-not-cache-result --display-phpunit-notices --testdox --filter testLoggerInfo
    public function testLoggerInfo(): void
    {
        self::bootKernel();

        /**
         * !!! IMPORTANT !!!
         *
         * AppService must be used in an App context (Controller, Command, Service, etc), so it must be called from the test container
         */

        /** @var AppService $appService */
        $appService = static::getContainer()->get(AppService::class);
        $appService->loggerInfo();

        $this->assertTrue(true);
    }
}

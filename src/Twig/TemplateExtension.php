<?php

namespace App\Twig;

use App\Utils\Utils;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\HttpFoundation\RequestStack;
use Twig\Environment;
use Twig\Extension\AbstractExtension;
use Twig\TwigFilter;
use Twig\TwigFunction;

final class TemplateExtension extends AbstractExtension
{
    public function __construct(
        #[Autowire('%kernel.environment%')] private readonly string $environment,
        protected EntityManagerInterface                            $em,
        protected RequestStack                                      $request,
        protected Environment                                       $twig,
        protected Utils                                             $utils
    )
    {
    }

    ##########################################################################################################################################################################################
    ###   FILTERS     ########################################################################################################################################################################

    /**
     * Twig filters
     */
    public function getFilters(): array
    {
        return [
            new TwigFilter('boolean', $this->boolean(...))
        ];
    }

    public function boolean(mixed $value): bool
    {
        return filter_var($value, FILTER_VALIDATE_BOOLEAN);
    }

    ##########################################################################################################################################################################################
    ###   FUNCTIONS     ######################################################################################################################################################################

    /**
     * Twig functions
     */
    public function getFunctions(): array
    {
        return [
            new TwigFunction('onDev', $this->onDev(...)),
            new TwigFunction('onProd', $this->onProd(...)),
            new TwigFunction('isTrue', $this->isTrue(...)),
            new TwigFunction('isFalse', $this->isFalse(...)),
            new TwigFunction('env', $this->getEnv(...)), // Twig call: env('APP_SECRET')
            new TwigFunction('sentryGetPublicKey', [$this->utils, 'sentryGetPublicKey']), // Twig call: sentryGetPublicKey()
        ];
    }

    public function onDev(): bool
    {
        return 'dev' === $this->environment;
    }

    public function onProd(): bool
    {
        return 'prod' === $this->environment;
    }

    public function isTrue(mixed $value): bool
    {
        return filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) === true;
    }

    public function isFalse(mixed $value): bool
    {
        return filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) === false;
    }

    public function getEnv(string $env): mixed
    {
        return $_ENV[$env] ?? null;
    }
}

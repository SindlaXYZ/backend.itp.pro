<?php

namespace App\Security;

use App\Entity\User;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Exception\CustomUserMessageAccountStatusException;
use Symfony\Component\Security\Core\User\UserCheckerInterface;
use Symfony\Component\Security\Core\User\UserInterface;
use Symfony\Contracts\Translation\TranslatorInterface;

/**
 * @see config/packages/security.yaml
 */
readonly class UserChecker implements UserCheckerInterface
{
    public function __construct(
        private TranslatorInterface $translator
    )
    {
    }

    public function checkPreAuth(UserInterface $user, ?TokenInterface $token = null): void
    {
        if (!$user instanceof User) {
            return;
        }

        if ($user->getStatusBitwiseHas(User::STATUS_SUSPENDED)) {
            $exception = new CustomUserMessageAccountStatusException($this->translator->trans('Your account is suspended.'), [], Response::HTTP_FORBIDDEN);
            $exception->setUser($user);
            throw $exception;
        } else if ($user->getStatusBitwiseHas(User::STATUS_DELETED)) {
            $exception = new CustomUserMessageAccountStatusException($this->translator->trans('Your account is deleted.'), [], Response::HTTP_GONE);
            $exception->setUser($user);
            throw $exception;
        }
    }

    public function checkPostAuth(UserInterface $user, ?TokenInterface $token = null): void
    {
        if (!$user instanceof User) {
            return;
        }
    }
}

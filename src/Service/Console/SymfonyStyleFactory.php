<?php
declare(strict_types=1);

namespace App\Service\Console;

use Symfony\Component\Console\Input\ArgvInput;
use Symfony\Component\Console\Output\ConsoleOutput;
use Symfony\Component\Console\Style\SymfonyStyle;

final class SymfonyStyleFactory
{
    public function create(): SymfonyStyle
    {
        $input  = new ArgvInput();
        $output = new ConsoleOutput();

        return new SymfonyStyle($input, $output);
    }
}

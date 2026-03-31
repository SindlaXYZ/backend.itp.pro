<?php

namespace App\DataFixtures\Middleware;

use App\Service\Console\SymfonyStyleFactory;
use Doctrine\Bundle\FixturesBundle\Fixture;
use Exception;
use Symfony\Component\Console\Style\SymfonyStyle;
use Symfony\Component\ErrorHandler\Error\UndefinedFunctionError;
use Symfony\Component\Finder\Finder;
use Symfony\Component\Yaml\Parser;

/**
 * @method SymfonyStyle symfonyStyle()
 * @method block(string $message)
 * @method title(string $message)
 * @method section(string $message)
 * @method text(string $message)
 * @method comment(string $message)
 * @method success(string $message)
 * @method error(string $message)
 * @method warning(string $message)
 * @method note(string $message)
 * @method info(string $message)
 * @method caution(string $message)
 */
abstract class DataFixturesMiddleware extends Fixture
{
    public function __call($methodName, $methodArguments)
    {
        global $argv;

        // Do not show warning message if this piece of code runs from `vendor/bin/behat` command
        if (!in_array('vendor/bin/behat', $argv)) {

            $symfonyStyle = new SymfonyStyleFactory()->create();

            if ('symfonyStyle' == $methodName) {
                /**
                 * Usage:  $ss = $this->symfonyStyle(); $ss->info('test');
                 */
                return $symfonyStyle;
            }

            if (isset($methodArguments[0]) && method_exists($symfonyStyle, $methodName)) {
                /**
                 * Usage: $this->>warning('Lorem ipsum');
                 */
                $symfonyStyle->$methodName($methodArguments[0]);
            } else {
                throw new UndefinedFunctionError(sprintf('"Attempted to call function "%s" from namespace "%s."', $methodName, __NAMESPACE__), new \Exception());
            }
        }
    }

    /**
     * @throws Exception
     */
    protected function readYamlFile($yamlFileName): iterable
    {
        $results = new Parser()->parse($this->readFile($yamlFileName));

        return $results ?? [];
    }

    /**
     * @throws Exception
     */
    protected function readFile(string $absoluteFilePath): string
    {
        if (!file_exists($absoluteFilePath)) {
            throw new Exception(sprintf('File %s does not exists.', $absoluteFilePath));
        }

        return file_get_contents($absoluteFilePath);
    }

    public function getAllNameSpaces($path): array
    {
        $filenames  = $this->getFilenames($path);
        $namespaces = [];
        foreach ($filenames as $filename) {
            $namespaces[] = $this->getFullNamespace($filename) . '\\' . $this->getClassName($filename);
        }
        return $namespaces;
    }

    protected function getClassName($filename): ?string
    {
        $directoriesAndFilename = explode('/', $filename);
        $filename               = array_pop($directoriesAndFilename);
        $nameAndExtension       = explode('.', $filename);
        $className              = array_shift($nameAndExtension);
        return $className;
    }

    protected function getFullNamespace($filename)
    {
        $lines         = file($filename);
        $array         = preg_grep('/^namespace /', $lines);
        $namespaceLine = array_shift($array);
        $match         = [];
        preg_match('/^namespace (.*);$/', $namespaceLine, $match);
        $fullNamespace = array_pop($match);

        return $fullNamespace;
    }

    protected function getFilenames($path): array
    {
        $finderFiles = Finder::create()->files()->in($path)->name('*.php');
        $filenames   = [];
        foreach ($finderFiles as $finderFile) {
            $filenames[] = $finderFile->getRealpath();
        }
        return $filenames;
    }

    public static function getAllGroups(?array $onlyThis = []): array
    {
        $groups = [];
        foreach (glob(dirname(__FILE__) . '/../*Fixtures.php') as $fixtureFileAbsolutePath) {
            $group = basename($fixtureFileAbsolutePath, '.php');
            if (empty($onlyThis) || (!empty($onlyThis) && in_array($group, $onlyThis))) {
                $groups[] = $group;
            }
        }

        return $groups;
    }
}

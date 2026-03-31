<?php

namespace App\Command\Dev;

use App\Command\Middleware\CommandMiddleware;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Cache\Adapter\ApcuAdapter;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Helper\ProgressBar;
use Symfony\Component\Console\Helper\Table;
use Symfony\Component\Console\Helper\TableStyle;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\BufferedOutput;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Question\ChoiceQuestion;
use Symfony\Component\Console\Question\ConfirmationQuestion;
use Symfony\Component\Console\Question\Question;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\DependencyInjection\ParameterBag\ParameterBagInterface;
use Symfony\Component\HttpClient\CachingHttpClient;
use Symfony\Component\HttpClient\HttpClient;
use Symfony\Component\HttpKernel\HttpCache\Store;
use Symfony\Component\Mailer\Mailer;
use Symfony\Component\Mailer\Transport;
use Symfony\Component\Mime\Email;
use Symfony\Component\Process\Exception\ProcessFailedException;
use Symfony\Component\Process\PhpExecutableFinder;
use Symfony\Component\Process\Process;
use Symfony\Component\Security\Core\Authentication\Token\UsernamePasswordToken;

#[AsCommand(
    name       : 'app:dev:demo',
    description: 'DEV only command'
)]
final class DemoCommand extends CommandMiddleware
{
    private ?BufferedOutput $bufferedOutput = null;

    public function __construct(
        #[Autowire('%kernel.environment%')] private readonly string $projectEnv,
        private readonly ?ContainerInterface                        $container,
        private readonly ParameterBagInterface                      $parameterBag,
        private readonly EntityManagerInterface                     $em,
    )
    {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this
            ->setHelp('This command allows you to test various development components and services.')
            // Mandatory
            ->addOption('action', null, InputOption::VALUE_REQUIRED)
            // Optional
            ->addOption('email', null, InputOption::VALUE_OPTIONAL)
            ->addOption('sqlLimit', null, InputOption::VALUE_OPTIONAL);
    }

    /**
     * This optional method is the first one executed for a command after configure() and is useful to initialize properties based on the input arguments and options.
     */
    protected function initialize(InputInterface $input, OutputInterface $output): void
    {
        parent::initialize($input, $output);
    }

    /**
     * This method is executed after initialize() and before execute(). Its purpose is to check if some of the options/arguments are missing and interactively ask the user for those values.
     *
     * This method is completely optional. If you are developing an internal console command, you probably should not implement this method because it requires quite a lot of work.
     * However, if the command is meant to be used by external users, this method is a nice way to fall back and prevent errors.
     */
    protected function interact(InputInterface $input, OutputInterface $output): void
    {
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        if (!in_array($this->projectEnv, ['dev', 'test'])) {
            $this->io->error(sprintf('This method is not allowed to run on the `%s` environment !', $_ENV['APP_ENV']));
            if (!($this->getHelper('question'))->ask($input, $output, new ConfirmationQuestion(
                'Continue with this action (y|yes)?',
                false,
                '/^(y|yes)/i'
            ))) {
                return self::FAILURE;
            }
        }

        return $this->try($input, $output, $this);
    }

    /**
     * clear; /usr/bin/php /srv/${DKZ_DOMAIN}/bin/console app:dev:demo --verbose --sqlLimit=1 --action=test
     */
    protected function test(): int
    {
        $reflection = new \ReflectionClass($this);
        $attributes = $reflection->getAttributes(AsCommand::class);
        $name       = $attributes[0]->getArguments()['name'] ?? 'Unknown Command Name';
        $this->io->success(sprintf("[%s] It works!", $name));

        return self::SUCCESS;
    }

    /**
     * clear; php bin/console app:dev:demo --action=processWorker
     */
    protected function processWorker(): int
    {
        sleep(mt_rand(1, 5));

        file_put_contents($this->parameterBag->get('root') . '/test.log', "\n" . date('H:i:s') . ' ' . microtime(false), FILE_APPEND);
        $this->outputWithTime('It works!');
        return self::SUCCESS;
    }

    /**
     * Run commands (workers) Asynchronous (start all the command same time)
     */
    protected function processExec(): int
    {
        // Find the absolute path of the executable PHP binary (eg: /usr/bin/php | /usr/bin/php7.4 | ...)
        $phpBinaryFinder = new PhpExecutableFinder();
        $phpBinaryPath   = $phpBinaryFinder->find();

        for ($iterations = 1; $iterations <= 5; ++$iterations) {
            /**
             * >/dev/null 2>&1 & will run the process in background
             * The command output will not be displayed here
             */
            exec(sprintf("%s %s/bin/console app:dev:demo --action=processWorker >/dev/null 2>&1 &", $phpBinaryPath, $this->parameterBag->get('root')));
        }

        return self::SUCCESS;
    }

    /**
     * Run commands (workers) Synchronous (start the next command after the previous one is finished)
     *
     * clear; php bin/console app:dev:demo --action=process
     */
    protected function process(): int
    {
        /**
         * https://symfony.com/index.php/doc/current/components/process.html
         *
         * run()    - execute a process
         * start()  - creates a background process, wait() for the process to finish
         *
         * PHP kills it after the response is returned back to the client and connection is closed
         */

        if (false) {
            $process = new Process(['ls', '-lsa']);
            $process->run();

            // When use "run()" the PID is empty
            $pid = $process->getPid();
            $this->output(sprintf('Process PID #%s', $pid));

            if (!$process->isSuccessful()) {
                throw new ProcessFailedException($process);
            }

            echo $process->getOutput();
            return self::SUCCESS;
        }

        if (false) {
            $process = new Process(['ls', '-lsa']);
            $process->start(); // start the process in background, but will be killed if parent command is terminated before child

            // When use "run()" the PID is NOT  empty
            $pid = $process->getPid();
            $this->output(sprintf('Process PID #%s', $pid));

            foreach ($process as $type => $data) {
                if ($process::OUT === $type) {
                    echo "\nRead from stdout: " . $data;
                } else { // $process::ERR === $type
                    echo "\nRead from stderr: " . $data;
                }
            }
            return self::SUCCESS;
        }

        // Find the absolute path of the executable PHP binary (eg: /usr/bin/php | /usr/bin/php7.4 | ...)
        $phpBinaryFinder = new PhpExecutableFinder();
        $phpBinaryPath   = $phpBinaryFinder->find();

        /**
         * This will not work, you will get "Exit Code: 127(Command not found)" because every
         * $process = new Process([sprintf('%s %s/bin/console app:dev:demo --action=test', $phpBinaryPath, $this->parameterBag->get('root'))]);
         */

        for ($iterations = 1; $iterations <= 5; ++$iterations) {
            $process = new Process([$phpBinaryPath, sprintf('%s/bin/console', $this->parameterBag->get('root')), 'app:dev:demo', '--action=processWorker']);
            // $this->output($process->getCommandLine());
            $process->setOptions(['create_new_console' => true]);
            $process->run();

            if (!$process->isSuccessful()) {
                throw new ProcessFailedException($process);

            } else {
                $processOutputLines = explode(PHP_EOL, trim($process->getOutput()));
                foreach ($processOutputLines as $processOutputLinename) {
                    $this->output("\t{$processOutputLinename}");
                }
            }
        }

        return self::SUCCESS;
    }

    /**
     * clear; php bin/console app:dev:demo --action=choice
     *
     * https://symfony.com/doc/current/components/console/helpers/questionhelper.html
     */
    protected function choice(): int
    {
        $helper   = $this->getHelper('question');
        $question = new ChoiceQuestion(
            'Please select your favorite color (defaults to red)',
            ['red', 'blue', 'yellow'],
            0
        );
        $question->setErrorMessage('Color %s is invalid.');

        $color = $helper->ask($this->input, $this->output, $question);
        $this->output->writeln('You have just selected: ' . $color);

        return self::SUCCESS;
    }

    /**
     * clear; php bin/console app:dev:demo --action=question
     *
     * https://symfony.com/doc/current/components/console/helpers/questionhelper.html
     */
    protected function question(): int
    {
        $helper = $this->getHelper('question');

        $favoriteColor = $helper->ask($this->input, $this->output, new Question("Please write your favorite color:\n", 'blue'));
        $this->output->writeln('You have just selected: ' . $favoriteColor);

        $questionFavoriteCar = new Question("Please write your favorite car:\n", 'blue');
        $favoriteCar         = $helper->ask($this->input, $this->output, $questionFavoriteCar);
        $this->output->writeln('You have just selected: ' . $favoriteCar);

        return self::SUCCESS;
    }

    /**
     * clear; php bin/console app:dev:demo --action=progressSimple
     */
    protected function progressSimple(): int
    {
        $item = 500;
        $this->io->success(sprintf('A number of %d Analytic found. Process it ...', $item));
        $this->io->progressStart($item);

        $i = 0;
        while ($i++ < $item) {
            usleep(mt_rand(0, 350000));
            $this->io->progressAdvance();
        }

        $this->io->progressFinish();

        return self::SUCCESS;
    }

    /**
     * clear; php bin/console app:dev:demo --action=progress
     *
     * https://symfony.com/doc/current/components/console/helpers/progressbar.html
     */
    protected function progress(): int
    {
        $item        = 500;
        $progressBar = new ProgressBar($this->output, $item);
        $progressBar->setFormat(' %current%/%max% [%bar%] %percent:3s%% in %elapsed:6s% / ETA %estimated:-6s%/ %memory:6s%');
        $progressBar->start();

        $i = 0;
        while ($i++ < $item) {
            usleep(mt_rand(0, 350000));

            // advances the progress bar 1 unit
            $progressBar->advance();

            // you can also advance the progress bar by more than 1 unit
            // $progressBar->advance(3);
        }

        // ensures that the progress bar is at 100%
        $progressBar->finish();

        $this->output->writeln("\n");

        return self::SUCCESS;
    }

    /**
     * clear; php bin/console app:dev:demo --action=table
     *
     * https://symfony.com/doc/current/components/console/helpers/table.html
     */
    protected function table(): int
    {
        $table = new Table($this->output);
        $table
            ->setHeaders(['ISBN', 'Title', 'Author'])
            ->setRows([
                ['99921-58-10-7', 'Divine Comedy', 'Dante Alighieri'],
                ['9971-5-0210-0', 'A Tale of Two Cities', 'Charles Dickens'],
                ['960-425-059-0', 'The Lord of the Rings', 'J. R. R. Tolkien'],
                ['80-902734-1-6', 'And Then There Were None', 'Agatha Christie'],
            ]);
        $table->render();

        return self::SUCCESS;
    }

    /**
     * Render table with another table in cell
     *
     * clear; php bin/console app:dev:demo --action=tableInTable
     *
     * https://symfony.com/doc/current/components/console/helpers/table.html
     */
    protected function tableInTable(): int
    {
        $this->_parentTable();

        return self::SUCCESS;
    }

    /**
     * clear; php bin/console app:dev:demo --action=logIn --email=test@example.com
     */
    protected function logIn(): int
    {
        /**
         * Get admin email
         */
        $helper = $this->getHelper('question');
        if (!$email = trim($this->input->getOption('email'))) {
            if (!$email = $helper->ask($this->input, $this->output, new Question("Email:\n", null))) {
                return self::FAILURE;
            }
        }

        // Get admin by email
        if (!$user = $this->em->getRepository(User::class)->findOneBy(['emailAddress' => $email])) {
            $this->io->error("User `{$email}` does not exit!");
            return self::FAILURE;
        }

        $token = new UsernamePasswordToken($user, 'main', $user->getRoles());
        $this->container->get('security.token_storage')->setToken($token);

        return self::SUCCESS;
    }

    /**
     * php bin/console app:dev:demo --action=cache
     */
    protected function cache(): int
    {
        $cache = new ApcuAdapter('', ($_ENV['APP_ENV'] == 'prod' ? 15 : 15));

        return $cache->get(sha1(__NAMESPACE__ . __CLASS__ . __METHOD__ . __LINE__), function () {
            $this->io->comment(
                mt_rand(1, 99999)
            );
            return self::SUCCESS;
        });
    }

    /**
     * clear; php bin/console app:dev:demo --action=crawler
     */
    protected function crawler(): int
    {
        $httpClient = HttpClient::create();
        $response   = $httpClient->request('GET', 'https://example.com');
        $statusCode = $response->getStatusCode();
        $this->outputWithTime("The crawler response is {$statusCode}");

        return self::SUCCESS;
    }

    /**
     * php bin/console app:dev:demo --action=crawlerWithCache
     */
    private function crawlerWithCache()
    {
        /**
         * Does it work only with response headers: Expires & Cache-Control public
         */

        $store      = new Store(sys_get_temp_dir() . '/');
        $client     = HttpClient::create();
        $client     = new CachingHttpClient($client, $store);
        $response   = $client->request('GET', 'http://worldtimeapi.org/api/timezone/Europe/Bucharest');
        $statusCode = $response->getContent();
        print_r($statusCode);
        die;
    }

    /**
     * clear; php bin/console app:dev:demo --action=email
     */
    protected function email(): int
    {
        $transport = Transport::fromDsn($_ENV['MAILER_DSN']);
        $mailer    = new Mailer($transport);
        $email     = new Email()
            ->from('hello@example.com')
            ->to('you@example.org')
            ->cc('cc@example.net')
            ->bcc('bcc@example.edu')
            ->replyTo('replyme@example.com')
            //->priority(Email::PRIORITY_HIGH)
            ->subject('Time for Symfony Mailer!')
            ->text('Sending emails is fun again!')
            ->html('<p>See Twig integration for better HTML integration!</p>');

        $mailer->send($email);

        $sentMessage = $transport->send($email);

        $this->io->comment($sentMessage->getMessageId()); // hash@1.com

        return self::SUCCESS;
    }

    private function _parentTable(): void
    {
        $this->bufferedOutput = new BufferedOutput(
            OutputInterface::VERBOSITY_NORMAL,
            true // true for decorated
        );

        $table = new Table($this->output);
        $this->_topLeftChildTable();
        $topRightChild = $this->bufferedOutput->fetch();
        $this->_bottomRightChildTable();
        $bottomRightChild = $this->bufferedOutput->fetch();

        $table->setHeaderTitle('Parent Table');
        $table->setheaders(['Left', 'Right']);
        $rows = [
            [$topRightChild, 'r1'],
            ['l2', $bottomRightChild],
        ];
        $table->setRows($rows);
        $table->render();
    }

    private function _topLeftChildTable(): void
    {
        $this->bufferedOutput = new BufferedOutput(
            OutputInterface::VERBOSITY_NORMAL,
            true // true for decorated
        );

        $table = new Table($this->bufferedOutput);
        $table->setStyle('box');
        $tableStyle = new TableStyle();
        $tableStyle
            ->setPadType(STR_PAD_BOTH);
        $table->setHeaderTitle('TL Child');
        $table->setheaders(['Left', 'Right']);
        $rows = [
            ['L1', 'R1'],
            ['L2', 'R2'],
        ];
        $table->setRows($rows);
        $table->render();
    }

    private function _bottomRightChildTable(): void
    {
        $this->bufferedOutput = new BufferedOutput(
            OutputInterface::VERBOSITY_NORMAL,
            true // true for decorated
        );

        $table = new Table($this->bufferedOutput);
        $table->setStyle('box');

        $tableStyle = new TableStyle();
        $tableStyle
            ->setPadType(STR_PAD_BOTH);
        $table->setHeaderTitle('BR Child');
        $table->setheaders(['Left', 'Right']);
        $rows = [
            ['L1', 'R1'],
            ['L2', 'R2'],
        ];
        $table->setRows($rows);
        $table->render();
    }
}

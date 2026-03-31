<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version19871220000000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    /**
     * yes | php bin/console doctrine:migrations:execute 'DoctrineMigrations\Version19871220000000' --down
     * yes | php bin/console doctrine:migrations:migrate 'DoctrineMigrations\Version19871220000000'
     */
    public function up(Schema $schema): void
    {
        $this->abortIf(false, 'Migration aborted example!');

        if (preg_match('/^(pgsql|postgres|postgresql|pdo_pgsql)/i', $_ENV['DATABASE_URL'])) {
            $this->addSql('CREATE EXTENSION IF NOT EXISTS unaccent');
        } else {
            $this->write(str_repeat('-', 60));
            $this->warnIf(true, 'PostgreSQL not detected, CREATE EXTENSION skipped;');
            $this->write(str_repeat('-', 60));
        }
    }

    public function down(Schema $schema): void
    {
        if (preg_match('/^(pgsql|postgres|postgresql|pdo_pgsql)/i', $_ENV['DATABASE_URL'])) {
            $this->addSql('DROP EXTENSION IF EXISTS unaccent');
        } else {
            $this->write(str_repeat('-', 90));
            $this->warnIf(true, 'PostgreSQL not detected, DROP EXTENSION skipped;');
            $this->write(str_repeat('-', 90));
        }
    }
}

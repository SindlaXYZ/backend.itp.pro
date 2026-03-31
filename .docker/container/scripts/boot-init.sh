#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# boot-init.sh — One-time initialization script.
#
# Copied to /etc/dockraft/scripts/boot-init.sh during image build (via Dockerfile COPY).
# Invoked once on the first container start by supervisord [program:boot-init].
# Self-deletes at the end so it does not run again on container restart.
#
# The healthcheck reads /root/sindla/boot-init-container-start-time to
# determine whether boot initialization is still in progress (< 10 min).
#
# Rules:
#   - Add one-time runtime init tasks here, NOT to the Dockerfile.
#   - Do NOT run long-lived processes here — this script must terminate.
#   - Keep idempotent where possible (guard with `command -v`, `[ -f ]`, etc.)
# -----------------------------------------------------------------------------

source /srv/${DKZ_DOMAIN}/.docker/container/scripts/lib.sh

# Record container start time so healthcheck.sh can track boot progress
echo "$(date +%s)" > /root/sindla/boot-init-container-start-time
log "boot-init started"

# -----------------------------------------------------------------------------
# One-time initialization tasks
# (extended by downstream Dockerfile sections)
# -----------------------------------------------------------------------------

# Write DKZ_* Docker environment variables to /etc/environment.
# Cron does not inherit the Docker/supervisord environment — it reads /etc/environment only.
# This must happen before cron starts so that ${DKZ_DOMAIN} and other vars expand in cron jobs.
log "Writing DKZ_* variables to /etc/environment"
printenv | grep "^DKZ_" | sed 's/=\(.*\)/="\1"/' >> /etc/environment

# Create nginx log directory (required before nginx starts; path matches sites-available/*.conf)
mkdir -p "/srv/${DKZ_DOMAIN}/.docker/.logs/nginx"

# Copy Angular skeleton if this is an Angular project and no package.json exists yet
if [ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ] && [ ! -f "/srv/${DKZ_DOMAIN}/package.json" ]; then
    if [ ! -d "/srv/${DKZ_DOMAIN}/.docker/stubs/angular/v${DKZ_NODEJS_ANGULAR_VERSION_INSTALL}" ]; then
        log "Angular skeleton not found — no stub directory for version '${DKZ_NODEJS_ANGULAR_VERSION_INSTALL}' at /srv/${DKZ_DOMAIN}/.docker/stubs/angular/v${DKZ_NODEJS_ANGULAR_VERSION_INSTALL}/"
    else
        log "Angular skeleton not found — copying stubs from /srv/${DKZ_DOMAIN}/.docker/stubs/angular/v${DKZ_NODEJS_ANGULAR_VERSION_INSTALL}/"
        cp -r "/srv/${DKZ_DOMAIN}/.docker/stubs/angular/v${DKZ_NODEJS_ANGULAR_VERSION_INSTALL}/." "/srv/${DKZ_DOMAIN}/"
        log "Angular skeleton copied for domain '${DKZ_DOMAIN}'"

        # Overlay Dockraft stubs on top of the Angular project
        cp "/srv/${DKZ_DOMAIN}/.docker/stubs/.gitignore-prepend" "/srv/${DKZ_DOMAIN}/.gitignore"
        cat "/srv/${DKZ_DOMAIN}/.gitignore-append" >> "/srv/${DKZ_DOMAIN}/.gitignore"
        rm -rf "/srv/${DKZ_DOMAIN}/.gitignore-append"
        log ".gitignore assembled for Angular ${DKZ_NODEJS_ANGULAR_VERSION_INSTALL}"
    fi
fi

# Install Composer when PHP is configured — required before any Symfony project setup or composer operations
if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" != "0" ]]; then
    # Install Composer if not already available
    if ! command -v composer &>/dev/null; then
        log "Composer not found — installing"
        curl --connect-timeout 60 https://getcomposer.org/installer | php -- && mv composer.phar /usr/local/bin/composer && chmod +x /usr/local/bin/composer
        log "Composer installed"
    fi
fi

# Copy Symfony skeleton if this is a Symfony project and no composer.json exists yet
if [ "${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" != "0" ]; then
    # Run only if the composer.json does not exist
    if [ ! -f "/srv/${DKZ_DOMAIN}/composer.json" ]; then
        if [ ! -d "/srv/${DKZ_DOMAIN}/.docker/stubs/symfony/v${DKZ_PHP_SYMFONY_VERSION_INSTALL}" ]; then
            log "Symfony skeleton not found — no stub directory for version '${DKZ_PHP_SYMFONY_VERSION_INSTALL}' at /srv/${DKZ_DOMAIN}/.docker/stubs/symfony/v${DKZ_PHP_SYMFONY_VERSION_INSTALL}/"
        else
            # Create Symfony project via composer create-project
            log "Creating Symfony ${DKZ_PHP_SYMFONY_VERSION_INSTALL} project via composer create-project"
            _symfony_tmp=$(mktemp -d)
            rm -rf "$_symfony_tmp"
            yes | composer create-project symfony/skeleton:^"${DKZ_PHP_SYMFONY_VERSION_INSTALL}" "$_symfony_tmp"
            cp -r "$_symfony_tmp/." "/srv/${DKZ_DOMAIN}/"
            rm -rf "$_symfony_tmp"
            log "Symfony ${DKZ_PHP_SYMFONY_VERSION_INSTALL} project created for domain '${DKZ_DOMAIN}'"

            log "Symfony skeleton not found — copying stubs from /srv/${DKZ_DOMAIN}/.docker/stubs/symfony/v${DKZ_PHP_SYMFONY_VERSION_INSTALL}/"
            cp -r "/srv/${DKZ_DOMAIN}/.docker/stubs/symfony/v${DKZ_PHP_SYMFONY_VERSION_INSTALL}/." "/srv/${DKZ_DOMAIN}/"
            log "Symfony skeleton copied for domain '${DKZ_DOMAIN}'"

            # Overlay Dockraft stubs on top of the Symfony project
            cp "/srv/${DKZ_DOMAIN}/.docker/stubs/.gitignore-prepend" "/srv/${DKZ_DOMAIN}/.gitignore"
            cat "/srv/${DKZ_DOMAIN}/.gitignore-append" >> "/srv/${DKZ_DOMAIN}/.gitignore"
            rm -rf "/srv/${DKZ_DOMAIN}/.gitignore-append"
            log ".gitignore assembled & appended for Symfony ${DKZ_PHP_SYMFONY_VERSION_INSTALL}"

            cat "/srv/${DKZ_DOMAIN}/.env-append" >> "/srv/${DKZ_DOMAIN}/.env"
            rm -rf /srv/"${DKZ_DOMAIN}"/.env-append
            log "/srv/${DKZ_DOMAIN}/.env appended for Symfony ${DKZ_PHP_SYMFONY_VERSION_INSTALL}"

            log "Update composer (config sort-packages true)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" config sort-packages true

            log "Removing sensio/framework-extra-bundle"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" remove sensio/framework-extra-bundle

            log "Installing Symfony Rate Limiter (symfony/rate-limiter)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies symfony/rate-limiter:^"${DKZ_PHP_SYMFONY_VERSION_INSTALL}"

            log "Installing Symfony Security (symfony/security-bundle)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies symfony/security-bundle:^"${DKZ_PHP_SYMFONY_VERSION_INSTALL}"
            if [[ -f "/srv/${DKZ_DOMAIN}/config/packages/security.yaml" ]]; then
                mv "/srv/${DKZ_DOMAIN}/config/packages/security.yaml" "/srv/${DKZ_DOMAIN}/config/packages/security.yaml.bak"
                sleep 1
            fi
            mv "/srv/${DKZ_DOMAIN}/config/packages/security.yaml.example" "/srv/${DKZ_DOMAIN}/config/packages/security.yaml"

            log "Installing Symfony Slack notifier (symfony/slack-notifier)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies symfony/slack-notifier:^"${DKZ_PHP_SYMFONY_VERSION_INSTALL}"

            log "Installing Doctrine (doctrine/orm & doctrine/doctrine-bundle & doctrine/doctrine-migrations-bundle & doctrine/doctrine-fixtures-bundle)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies doctrine/orm doctrine/doctrine-bundle doctrine/doctrine-migrations-bundle doctrine/doctrine-fixtures-bundle
            if [[ -f "/srv/${DKZ_DOMAIN}/config/packages/doctrine.yaml" ]]; then
                mv "/srv/${DKZ_DOMAIN}/config/packages/doctrine.yaml" "/srv/${DKZ_DOMAIN}/config/packages/doctrine.yaml.bak"
                sleep 1
            fi
            mv "/srv/${DKZ_DOMAIN}/config/packages/doctrine.yaml.example" "/srv/${DKZ_DOMAIN}/config/packages/doctrine.yaml"

            log "Installing Gedmo Doctrine Extensions/SoftDeleteableFilter (gedmo/doctrine-extensions)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies gedmo/doctrine-extensions

            log "Installing DB Auditor (damienharper/auditor-bundle)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies damienharper/auditor-bundle
            if [[ -f "/srv/${DKZ_DOMAIN}/config/packages/dh_auditor.yaml" ]]; then
                mv "/srv/${DKZ_DOMAIN}/config/packages/dh_auditor.yaml" "/srv/${DKZ_DOMAIN}/config/packages/dh_auditor.yaml.bak"
                sleep 1
            fi
            mv "/srv/${DKZ_DOMAIN}/config/packages/dh_auditor.yaml.example" "/srv/${DKZ_DOMAIN}/config/packages/dh_auditor.yaml"
            dotENV "/srv/${DKZ_DOMAIN}/.env" after DATABASE_URL "AUDIT_DATABASE_URL="

            _bundles_php="/srv/${DKZ_DOMAIN}/config/bundles.php"
            if ! grep -q "DHAuditorBundle" "$_bundles_php"; then
                _tmp="${_bundles_php}.bundles_tmp"
                while IFS= read -r _line || [[ -n "$_line" ]]; do
                    [[ "$_line" == "];" ]] && printf '    DH\\AuditorBundle\\DHAuditorBundle::class => ['"'"'all'"'"' => true],\n'
                    printf '%s\n' "$_line"
                done < "$_bundles_php" > "$_tmp" && mv "$_tmp" "$_bundles_php"
                log "Registered DHAuditorBundle in config/bundles.php"
            else
                log "DHAuditorBundle already registered in config/bundles.php — skipping"
            fi

            log "Installing PHP Mailer (phpmailer/phpmailer)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies phpmailer/phpmailer

            log "Installing Device detector (matomo/device-detector)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies matomo/device-detector

            log "Installing CSV read/write (league/csv)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies league/csv

            log "Installing DOM PDF - HTML to PDF converter (dompdf/dompdf)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies dompdf/dompdf

            log "Installing Image Manipulator (intervention/image)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies intervention/image

            log "Installing Amazon SDK (aws/aws-sdk-php)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies aws/aws-sdk-php

            log "Installing Sentry (sentry/sentry-symfony)"
            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies sentry/sentry-symfony

            if [ "${DKZ_RABBITMQ_INSTALL:-0}" != "0" ]; then
                log "Installing AMQP protocol for RabbitMQ (php-amqplib/php-amqplib)"
                yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies php-amqplib/php-amqplib
            fi

            # Install API Platform if configured
            if [ "${DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL:-0}" != "0" ]; then
                log "Installing API Platform ^${DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL}"
                yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies api-platform/core:^"${DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL}"

                log "Installing JWT (Json Web Token) authentication for your Symfony API"
                yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies lexik/jwt-authentication-bundle
                if [[ -f "/srv/${DKZ_DOMAIN}/config/packages/lexik_jwt_authentication.yaml" ]]; then
                    mv "/srv/${DKZ_DOMAIN}/config/packages/lexik_jwt_authentication.yaml" "/srv/${DKZ_DOMAIN}/config/packages/lexik_jwt_authentication.yaml.bak"
                    sleep 1
                fi
                mv "/srv/${DKZ_DOMAIN}/config/packages/lexik_jwt_authentication.yaml.example" "/srv/${DKZ_DOMAIN}/config/packages/lexik_jwt_authentication.yaml"

                log "Installing CORS (Cross-Origin Resource Sharing) headers support for Symfony"
                yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies nelmio/cors-bundle
                if [[ -f "/srv/${DKZ_DOMAIN}/config/packages/nelmio_cors.yaml" ]]; then
                    mv "/srv/${DKZ_DOMAIN}/config/packages/nelmio_cors.yaml" "/srv/${DKZ_DOMAIN}/config/packages/nelmio_cors.yaml.bak"
                    sleep 1
                fi
                mv "/srv/${DKZ_DOMAIN}/config/packages/nelmio_cors.yaml.example" "/srv/${DKZ_DOMAIN}/config/packages/nelmio_cors.yaml"
            else
                rm -rf /srv/"${DKZ_DOMAIN}"/config/packages/api_platform.yaml
                rm -rf /srv/"${DKZ_DOMAIN}"/config/packages/lexik_jwt_authentication.yaml.example
                rm -rf /srv/"${DKZ_DOMAIN}"/config/packages/nelmio_cors.yaml.example
            fi

            # Install Aurora (if configured) and it's dependencies
            if [ "${DKZ_PHP_SYMFONY_AURORA_INSTALL:-0}" != "0" ]; then
                log "Installing Aurora ^${DKZ_PHP_SYMFONY_VERSION_INSTALL}"
                yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --with-all-dependencies sindla/aurora:^"${DKZ_PHP_SYMFONY_VERSION_INSTALL}"
                cat "/srv/${DKZ_DOMAIN}/.docker/stubs/symfony/v${DKZ_PHP_SYMFONY_VERSION_INSTALL}/config/services.aurora.yaml" >> "/srv/${DKZ_DOMAIN}/config/services.yaml"
                rm -rf /srv/"${DKZ_DOMAIN}"/config/services.aurora.yaml
            fi

            if [[ "$DKZ_ENV" == "DEV" ]]; then
                log "Installing PHPUnit & PHP STAN & PSALM"
                yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --dev --with-all-dependencies \
                  phpunit/php-code-coverage \
                  phpstan/phpstan-symfony \
                  symfony/phpunit-bridge:^"${DKZ_PHP_SYMFONY_VERSION_INSTALL}" \
                  phpstan/phpstan-doctrine \
                  symfony/test-pack \
                  dama/doctrine-test-bundle \
                  psalm/plugin-symfony ;

                if [[ -f "/srv/${DKZ_DOMAIN}/phpunit.dist.xml" ]]; then
                    mv "/srv/${DKZ_DOMAIN}/phpunit.dist.xml" "/srv/${DKZ_DOMAIN}/phpunit.dist.xml.bak"
                    sleep 1
                fi
                mv "/srv/${DKZ_DOMAIN}/phpunit-13.0.dist.xml" "/srv/${DKZ_DOMAIN}/phpunit.dist.xml.bak"
            fi

            yes | composer --working-dir="/srv/${DKZ_DOMAIN}" require --no-scripts \
              ext-ctype:* \
              ext-curl:* \
              ext-gmp:* \
              ext-iconv:* \
              ext-intl:* \
              ext-json:* \
              ext-mbstring:* \
              ext-openssl:* \
              ext-pcre:* \
              ext-pdo_pgsql:* \
              ext-session:* \
              ext-simplexml:* \
              ext-tokenizer:* \
              ext-zend-opcache:* ;

            # Remove unnecessary files
            rm -rf /srv/"${DKZ_DOMAIN}"/migrations/
            rm -rf /srv/"${DKZ_DOMAIN}"/src/{ApiResource,Controller,Entity,Repository}/.gitignore
            rm -rf /srv/"${DKZ_DOMAIN}"/.env.dev
            rm -rf /srv/"${DKZ_DOMAIN}"/compose.{override.,}yaml
        fi
    fi

    # Patch composer.json — update .config.platform.php and Aurora script handlers
    if [ "${DKZ_SELF_MODIFY:-0}" == "1" ] && [ -f "/srv/${DKZ_DOMAIN}/composer.json" ]; then
        if command -v php &>/dev/null && command -v jq &>/dev/null; then
            _php_ver_ab=$(php -v | grep ^PHP | cut -d' ' -f2 | cut -d '.' -f 1,2)
            log "composer.json: setting .config.platform.php to ${_php_ver_ab}"
            _php_ver_ab="${_php_ver_ab}" jq --tab '.config.platform |= . + {"php": env._php_ver_ab}' "/srv/${DKZ_DOMAIN}/composer.json" >"/srv/${DKZ_DOMAIN}/composer.json.new" && mv "/srv/${DKZ_DOMAIN}/composer.json.new" "/srv/${DKZ_DOMAIN}/composer.json"
            sed -i -e 's/\t/    /g' "/srv/${DKZ_DOMAIN}/composer.json"
            log "composer.json: .config.platform.php patched"
        fi

        if [ "${DKZ_PHP_SYMFONY_AURORA_INSTALL:-0}" != "0" ] && command -v jq &>/dev/null; then
            log "composer.json: applying Aurora autoload and script handler patches"
            jq --tab '.autoload |= . + {"exclude-from-classmap": ["/src/Migrations"]}' "/srv/${DKZ_DOMAIN}/composer.json" >"/srv/${DKZ_DOMAIN}/composer.json.new" && mv "/srv/${DKZ_DOMAIN}/composer.json.new" "/srv/${DKZ_DOMAIN}/composer.json"
            if ! grep -q 'Sindla\\\\Bundle\\\\AuroraBundle\\\\Composer\\\\ScriptHandler::postInstall' "/srv/${DKZ_DOMAIN}/composer.json"; then
                jq --tab '.scripts."post-install-cmd" |= . + ["Sindla\\Bundle\\AuroraBundle\\Composer\\ScriptHandler::postInstall"]' "/srv/${DKZ_DOMAIN}/composer.json" >"/srv/${DKZ_DOMAIN}/composer.json.new" && mv "/srv/${DKZ_DOMAIN}/composer.json.new" "/srv/${DKZ_DOMAIN}/composer.json"
            fi
            if ! grep -q 'Sindla\\\\Bundle\\\\AuroraBundle\\\\Composer\\\\ScriptHandler::postUpdate' "/srv/${DKZ_DOMAIN}/composer.json"; then
                jq --tab '.scripts."post-update-cmd" |= . + ["Sindla\\Bundle\\AuroraBundle\\Composer\\ScriptHandler::postUpdate"]' "/srv/${DKZ_DOMAIN}/composer.json" >"/srv/${DKZ_DOMAIN}/composer.json.new" && mv "/srv/${DKZ_DOMAIN}/composer.json.new" "/srv/${DKZ_DOMAIN}/composer.json"
            fi
            sed -i -e 's/\t/    /g' "/srv/${DKZ_DOMAIN}/composer.json"
            log "composer.json: Aurora patches applied"
        fi
    fi

    # Patch doctrine.yaml — set server_version to the configured PostgreSQL version
    if [ "${DKZ_SELF_MODIFY:-0}" == "1" ] && [ "${DKZ_POSTGRESQL_VERSION_INSTALL:-0}" != "0" ] && [ -f "/srv/${DKZ_DOMAIN}/config/packages/doctrine.yaml" ]; then
        log "doctrine.yaml: setting server_version to ${DKZ_POSTGRESQL_VERSION_INSTALL}"
        sed -i -e "s/# server_version: '.*'/server_version: '${DKZ_POSTGRESQL_VERSION_INSTALL}'/g" "/srv/${DKZ_DOMAIN}/config/packages/doctrine.yaml"
        sed -i -e "s/#server_version: '.*'/server_version: '${DKZ_POSTGRESQL_VERSION_INSTALL}'/g" "/srv/${DKZ_DOMAIN}/config/packages/doctrine.yaml"
        sed -i -e "s/server_version: '.*'/server_version: '${DKZ_POSTGRESQL_VERSION_INSTALL}'/g" "/srv/${DKZ_DOMAIN}/config/packages/doctrine.yaml"
        log "doctrine.yaml: server_version patched"
    fi

    # Create Symfony .env.local with machine-specific overrides (git ignored, not committed)
    log "Creating Symfony .env.local"
    cp "/srv/${DKZ_DOMAIN}/.env" "/srv/${DKZ_DOMAIN}/.env.local"

    # Generate a unique APP_SECRET
    _app_secret=$(cat /proc/sys/kernel/random/uuid)
    sed -i "s/APP_SECRET=.*/APP_SECRET=${_app_secret}/" "/srv/${DKZ_DOMAIN}/.env.local"
    log ".env.local: APP_SECRET set to new UUID"

    # Configure DATABASE_URL
    if [ "${DKZ_POSTGRESQL_VERSION_INSTALL:-0}" != "0" ] && [ -n "${DKZ_POSTGRESQL_USERNAME}" ] && [ -n "${DKZ_POSTGRESQL_DATABASE}" ]; then
        _db_url="pgsql://${DKZ_POSTGRESQL_USERNAME}:${DKZ_POSTGRESQL_PASSWORD}@127.0.0.1:5432/${DKZ_POSTGRESQL_DATABASE}?host=/var/run/postgresql"
        grep -q "^DATABASE_URL=" "/srv/${DKZ_DOMAIN}/.env.local" \
          && sed -i "s|^DATABASE_URL=.*|DATABASE_URL=${_db_url}|" "/srv/${DKZ_DOMAIN}/.env.local" \
          || echo "DATABASE_URL=${_db_url}" >> "/srv/${DKZ_DOMAIN}/.env.local"
        if grep -q "^AUDIT_DATABASE_URL=" "/srv/${DKZ_DOMAIN}/.env.local"; then
            sed -i "s|^AUDIT_DATABASE_URL=.*|AUDIT_DATABASE_URL=pgsql://${DKZ_POSTGRESQL_USERNAME}:${DKZ_POSTGRESQL_PASSWORD}@127.0.0.1:5432/${DKZ_POSTGRESQL_DATABASE}_audit?host=/var/run/postgresql|" "/srv/${DKZ_DOMAIN}/.env.local"
        fi
        log ".env.local: DATABASE_URL set for PostgreSQL"
    elif [ "${DKZ_MYSQL_VERSION_INSTALL:-0}" != "0" ] && [ -n "${DKZ_MYSQL_USERNAME}" ] && [ -n "${DKZ_MYSQL_DATABASE}" ]; then
        _db_url="mysql://${DKZ_MYSQL_USERNAME}:${DKZ_MYSQL_PASSWORD}@127.0.0.1:3306/${DKZ_MYSQL_DATABASE}"
        grep -q "^DATABASE_URL=" "/srv/${DKZ_DOMAIN}/.env.local" \
          && sed -i "s|^DATABASE_URL=.*|DATABASE_URL=${_db_url}|" "/srv/${DKZ_DOMAIN}/.env.local" \
          || echo "DATABASE_URL=${_db_url}" >> "/srv/${DKZ_DOMAIN}/.env.local"
        if grep -q "^AUDIT_DATABASE_URL=" "/srv/${DKZ_DOMAIN}/.env.local"; then
            sed -i "s|^AUDIT_DATABASE_URL=.*|AUDIT_DATABASE_URL=mysql://${DKZ_MYSQL_USERNAME}:${DKZ_MYSQL_PASSWORD}@127.0.0.1:3306/${DKZ_MYSQL_DATABASE}_audit|" "/srv/${DKZ_DOMAIN}/.env.local"
        fi
        log ".env.local: DATABASE_URL set for MySQL"
    else
        _db_url="sqlite:///%kernel.project_dir%/var/app.db"
        grep -q "^DATABASE_URL=" "/srv/${DKZ_DOMAIN}/.env.local" \
          && sed -i "s|^DATABASE_URL=.*|DATABASE_URL=${_db_url}|" "/srv/${DKZ_DOMAIN}/.env.local" \
          || echo "DATABASE_URL=${_db_url}" >> "/srv/${DKZ_DOMAIN}/.env.local"
        log ".env.local: DATABASE_URL set for SQLite (fallback)"
    fi

    # MaxMind license key (if configured — Aurora feature)
    if [ -n "${DKZ_MAXMIND_LICENSE_KEY}" ] && [ "${DKZ_MAXMIND_LICENSE_KEY}" != "0" ]; then
        grep -q "^MAXMIND_LICENSE_KEY=" "/srv/${DKZ_DOMAIN}/.env.local" \
          && sed -i "s|MAXMIND_LICENSE_KEY=.*|MAXMIND_LICENSE_KEY=${DKZ_MAXMIND_LICENSE_KEY}|" "/srv/${DKZ_DOMAIN}/.env.local" \
          || echo "MAXMIND_LICENSE_KEY=${DKZ_MAXMIND_LICENSE_KEY}" >> "/srv/${DKZ_DOMAIN}/.env.local"
    fi

    # Override Symfony cache/build/log dirs (only when DKZ_SELF_MODIFY=1)
    if [ "${DKZ_SELF_MODIFY:-0}" == "1" ]; then
        if [ "${DKZ_ENV}" == "DEV" ]; then
            printf '\n###> dockraft/override symfony dirs ###\nAPP_CACHE_DIR=/dev/shm/%s/cache\nAPP_BUILD_DIR=/tmp/%s/build\nAPP_LOG_DIR=/tmp/%s/.docker/.logs\n###< dockraft/override symfony dirs ###\n' \
              "${DKZ_DOMAIN}" "${DKZ_DOMAIN}" "${DKZ_DOMAIN}" >> "/srv/${DKZ_DOMAIN}/.env.local"
        else
            printf '\n###> dockraft/override symfony dirs ###\nAPP_CACHE_DIR=/dev/shm/%s/cache\nAPP_BUILD_DIR=/srv/%s/var/build\nAPP_LOG_DIR=/srv/%s/.docker/.logs\n###< dockraft/override symfony dirs ###\n' \
              "${DKZ_DOMAIN}" "${DKZ_DOMAIN}" "${DKZ_DOMAIN}" >> "/srv/${DKZ_DOMAIN}/.env.local"
        fi
    fi

    # PROD: force production environment flags
    if [ "${DKZ_ENV}" == "PROD" ]; then
        sed -i "s/APP_ENV=.*/APP_ENV=prod/" "/srv/${DKZ_DOMAIN}/.env.local"
        grep -q "^APP_DEBUG=" "/srv/${DKZ_DOMAIN}/.env.local" \
          && sed -i "s/APP_DEBUG=.*/APP_DEBUG=0/" "/srv/${DKZ_DOMAIN}/.env.local" \
          || echo "APP_DEBUG=0" >> "/srv/${DKZ_DOMAIN}/.env.local"
    fi
    log ".env.local created for domain '${DKZ_DOMAIN}'"

    # DEV: run cc (cache:clear + cache:warmup + vendor7Zip) after first-time project setup
    if [ "${DKZ_ENV}" == "DEV" ]; then
        source "/srv/${DKZ_DOMAIN}/.docker/container/scripts/symfony.sh"
        cc
    fi
fi

if [ "${DKZ_ENV}" == "DEV" ]; then
    if [[ -d "/srv/${DKZ_DOMAIN}/.docker/.claude/agents/" ]] ; then
        cp -rf "/srv/${DKZ_DOMAIN}/.docker/.claude/agents/" "/srv/${DKZ_DOMAIN}/.claude"
        rm -rf "/srv/${DKZ_DOMAIN}/.docker/.claude/"
    fi
fi

# Replace __DOMAIN__ placeholder (all project types)
find "/srv/${DKZ_DOMAIN}" -maxdepth 6 \
  -not -path "*/node_modules/*" \
  -type f \( -name "*.json" -o -name "*.ts" -o -name "*.html" -o -name "*.css" -o -name "*.md" -o -name "*.yaml" -o -name "*.yml" \) \
  | xargs sed -i "s/__DOMAIN__/${DKZ_DOMAIN}/g"
log "__DOMAIN__ has been replaced with '${DKZ_DOMAIN}'"

# Create PostgreSQL user and database (first-time only).
# DKZ_POSTGRESQL_PASSWORD is a runtime secret — it cannot be passed as --build-arg,
# so user/DB creation must happen here at first container start rather than in the Dockerfile.
if [ "${DKZ_POSTGRESQL_VERSION_INSTALL:-0}" != "0" ] && [ -n "${DKZ_POSTGRESQL_USERNAME}" ] && [ -n "${DKZ_POSTGRESQL_DATABASE}" ] && [ -n "${DKZ_POSTGRESQL_PASSWORD}" ]; then
    log "PostgreSQL: starting service for initial user/database setup"
    service postgresql start
    sleep 5
    su - postgres <<EOF
psql -c "CREATE USER \"${DKZ_POSTGRESQL_USERNAME}\" WITH SUPERUSER PASSWORD '${DKZ_POSTGRESQL_PASSWORD}';"
createdb -O "${DKZ_POSTGRESQL_USERNAME}" "${DKZ_POSTGRESQL_DATABASE}"
EOF
    log "PostgreSQL: user '${DKZ_POSTGRESQL_USERNAME}' and database '${DKZ_POSTGRESQL_DATABASE}' created"
fi

# PROD: run initial deploy on first boot (--skip-git: Dockerfile already did a fresh git clone)
# Runs after PostgreSQL setup so doctrine:migrations:migrate has a database to connect to
if [ "${DKZ_ENV}" == "PROD" ] && [ -f "/srv/${DKZ_DOMAIN}/composer.json" ] && [ ! -d "/srv/${DKZ_DOMAIN}/vendor" ]; then
    bash "/srv/${DKZ_DOMAIN}/.docker/container/scripts/deploy.sh" --skip-git
fi

log "boot-init done"

# Self-delete — ensures this script does not run again on container restart
rm -f /etc/dockraft/scripts/boot-init.sh

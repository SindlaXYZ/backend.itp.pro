#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# symfony.sh — Symfony console shortcut functions.
#
# Sourced by motd.sh on every interactive shell session (PHP/Symfony projects only).
# Each function can also be called from other scripts by sourcing this file.
#
# Usage: source /srv/${DKZ_DOMAIN}/.docker/container/scripts/symfony.sh
# -----------------------------------------------------------------------------

# DEV-only composer aliases: ci, cu, cuf
if [[ "$DKZ_ENV" == "DEV" ]]; then
    alias ci="cd /srv/${DKZ_DOMAIN} && composer install && chown -R www-data:www-data /tmp/${DKZ_DOMAIN}/"
    alias cu="cd /srv/${DKZ_DOMAIN} && composer update && chown -R www-data:www-data /tmp/${DKZ_DOMAIN}/"
    alias cuf="cd /srv/${DKZ_DOMAIN} && composer update --ignore-platform-reqs && chown -R www-data:www-data /tmp/${DKZ_DOMAIN}/"
    alias tests="cd /srv/${DKZ_DOMAIN} && php bin/phpunit"
fi

# Guard: no-op when Symfony is not installed
if [[ "${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" == "0" ]]; then
    return 0 2>/dev/null || exit 0
fi

_CONSOLE="/srv/${DKZ_DOMAIN}/bin/console"

# DEV-only functions: cc (cache clear + vendor archive) and vendor7Zip
if [[ "$DKZ_ENV" == "DEV" ]]; then
    # vendor7Zip — Create a max-compression 7zip archive of vendor/ for IDE autocompletion.
    # Working directory: /srv/${DKZ_DOMAIN}/. Output: vendor.7z
    vendor7Zip() {
        echo "Archiving vendor/ (max compression) — this may take a few minutes ..."
        cd "/srv/${DKZ_DOMAIN}" || { echo "ERROR: cannot cd to /srv/${DKZ_DOMAIN}/"; return 1; }
        rm -f vendor.7z
        7z a -mx=9 -mmt=on vendor.7z vendor
        echo -e "${CYELLOW}vendor.7z created — extract to your project root for IDE autocompletion${CDEF}"
    }

    # cc — Clear Symfony cache and warm up, then archive vendor/ via vendor7Zip.
    cc() {
        cd "/srv/${DKZ_DOMAIN}" || { echo "ERROR: cannot cd to /srv/${DKZ_DOMAIN}/"; return 1; }
        APP_ENV=dev /usr/bin/php "$_CONSOLE" cache:clear
        APP_ENV=dev /usr/bin/php "$_CONSOLE" cache:warmup
        vendor7Zip
    }
fi

# Returns 0 (true) if doctrine/doctrine-migrations-bundle is in composer.json, 1 (false) otherwise
doctrine_migrations_installed() {
    grep -q '"doctrine/doctrine-migrations-bundle"' "/srv/${DKZ_DOMAIN}/composer.json" 2>/dev/null
}

doctrine_migrations_not_installed() {
    echo -e "${CRED}doctrine/doctrine-migrations-bundle is not installed${CDEF}"
}

# Database — sync metadata storage + schema validate
dbv() {
    cd "/srv/${DKZ_DOMAIN}" || return 1
    if doctrine_migrations_installed; then
        APP_DEBUG=0 /usr/bin/php "$_CONSOLE" doctrine:migrations:sync-metadata-storage
    fi
    APP_DEBUG=0 /usr/bin/php "$_CONSOLE" doctrine:schema:validate
}

# Database — sync metadata storage + migration status
dbs() {
    cd "/srv/${DKZ_DOMAIN}" || return 1
    if doctrine_migrations_installed; then
        APP_DEBUG=0 /usr/bin/php "$_CONSOLE" doctrine:migrations:sync-metadata-storage
        APP_DEBUG=0 /usr/bin/php "$_CONSOLE" doctrine:migrations:status
    else
        doctrine_migrations_not_installed
    fi
}

# Database — sync metadata storage + migration list
dbl() {
    cd "/srv/${DKZ_DOMAIN}" || return 1
    if doctrine_migrations_installed; then
        APP_DEBUG=0 /usr/bin/php "$_CONSOLE" doctrine:migrations:sync-metadata-storage
        APP_DEBUG=0 /usr/bin/php "$_CONSOLE" doctrine:migrations:list
    else
        doctrine_migrations_not_installed
    fi
}

# Database — generate migration diff
dbd() {
    cd "/srv/${DKZ_DOMAIN}" || return 1
    [[ "$DKZ_ENV" == "PROD" ]] && return 0
    if doctrine_migrations_installed; then
        yes | APP_DEBUG=0 /usr/bin/php "$_CONSOLE" doctrine:migrations:diff
    else
        doctrine_migrations_not_installed
    fi
}

# Database — run pending migrations
dbm() {
    cd "/srv/${DKZ_DOMAIN}" || return 1
    if doctrine_migrations_installed; then
        yes | APP_DEBUG=0 /usr/bin/php "$_CONSOLE" doctrine:migrations:migrate
    else
        doctrine_migrations_not_installed
    fi
}

# Symfony — about
symabout() {
    /usr/bin/php "$_CONSOLE" about
}

# Symfony — debug:container --deprecations
symdeps() {
    /usr/bin/php "$_CONSOLE" debug:container --deprecations
}

# Symfony — debug:container --env-vars
symenvs() {
    /usr/bin/php "$_CONSOLE" debug:container --env-vars
}

# Symfony — debug:router (all routes)
symroutes() {
    /usr/bin/php "$_CONSOLE" debug:router
}

# Symfony — debug:router <route-name> (single route with argument)
symroute() {
    /usr/bin/php "$_CONSOLE" debug:router "$@"
}

# Symfony — debug:dotenv
symdotenv() {
    /usr/bin/php "$_CONSOLE" debug:dotenv
}

# Symfony — debug:container --parameters
symparameters() {
    /usr/bin/php "$_CONSOLE" debug:container --parameters
}

# Symfony — debug:container --deprecations (alias of symdeps)
sdepres() {
    /usr/bin/php "$_CONSOLE" debug:container --deprecations
}

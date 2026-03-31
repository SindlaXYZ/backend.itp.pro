#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# deploy.sh — Production deploy script.
#
# Called via the 'deploy' alias (defined in motd.sh for PROD environments).
# Handles both PHP/Symfony and Angular/NodeJS project types.
# Exits immediately if DKZ_ENV != PROD.
# -----------------------------------------------------------------------------

# Source DKZ_* variables (not inherited in all shell sessions)
[ -f /etc/environment ] && source /etc/environment

source "/srv/${DKZ_DOMAIN}/.docker/container/scripts/lib.sh"

if [[ "$DKZ_ENV" != "PROD" ]]; then
    log "deploy.sh: DKZ_ENV=${DKZ_ENV} — deploy runs in PROD only. Skipping."
    exit 0
fi

_SKIP_GIT=false
[[ "$1" == "--skip-git" ]] && _SKIP_GIT=true

log "Starting deploy for ${DKZ_DOMAIN} (branch: ${DKZ_GIT_BRANCH_PRODUCTION})"

# Fix ownership on runtime temp files
chown -R www-data:www-data "/tmp/${DKZ_DOMAIN}/"

# Git: fetch and reset to production branch
if [ "$_SKIP_GIT" == false ]; then
    cd "/srv/${DKZ_DOMAIN}/" || { log "ERROR: cannot cd to /srv/${DKZ_DOMAIN}/"; exit 1; }
    git config pull.rebase false
    git fetch origin
    git reset --hard "origin/${DKZ_GIT_BRANCH_PRODUCTION}"
    git pull origin "${DKZ_GIT_BRANCH_PRODUCTION}"
    git fetch --tags
    log "Git pull completed (branch: ${DKZ_GIT_BRANCH_PRODUCTION})"
fi

# =============================================================================
# PHP / Symfony deploy steps
# =============================================================================

if [[ "${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" != "0" ]]; then
    log "Running Symfony deploy steps"

    # Lock to stable releases
    sed -i -e 's/"minimum-stability": ".*"/"minimum-stability": "stable"/g' "/srv/${DKZ_DOMAIN}/composer.json"

    composer install --no-dev --optimize-autoloader --working-dir="/srv/${DKZ_DOMAIN}"

    symfony_run_migrations

    composer dump-autoload --no-dev --optimize --classmap-authoritative --working-dir="/srv/${DKZ_DOMAIN}"

    php "/srv/${DKZ_DOMAIN}/bin/console" cache:clear --no-warmup --env=prod
    php "/srv/${DKZ_DOMAIN}/bin/console" cache:warmup --env=prod

    # Lint DI container
    php "/srv/${DKZ_DOMAIN}/bin/console" lint:container

    # Fix ownership
    chown -R www-data:www-data "/srv/${DKZ_DOMAIN}/var/" 2>/dev/null || true
    chown -R www-data:www-data "/tmp/${DKZ_DOMAIN}/"

    # Restart PHP-FPM
    service "php${DKZ_PHP_VERSION_INSTALL}-fpm" stop
    sleep 1
    service "php${DKZ_PHP_VERSION_INSTALL}-fpm" start

    log "Symfony deploy completed"
fi

# =============================================================================
# Angular / NodeJS deploy steps
# =============================================================================

if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
    log "Running Angular deploy steps"

    # Source nvm so node/npm/ng are available
    export NVM_DIR="/root/.nvm"
    [ -s "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh"

    npm install --prefix "/srv/${DKZ_DOMAIN}"
    npm run build --prefix "/srv/${DKZ_DOMAIN}"

    supervisorctl restart angular

    log "Angular deploy completed"
fi

# Sync crontab
install_crontab

log "Deploy completed for ${DKZ_DOMAIN}"

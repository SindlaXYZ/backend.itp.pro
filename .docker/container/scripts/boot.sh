#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# boot.sh — Runs on every container start, after boot-init.sh completes.
# Invoked by supervisord [program:boot] which waits for boot-init.sh to
# self-delete before executing this script.
# -----------------------------------------------------------------------------

source /srv/${DKZ_DOMAIN}/.docker/container/scripts/lib.sh

# -----------------------------------------------------------------------------

log "##########################################################################"
log "### START BOOTING — ENV=${DKZ_ENV} / PHP=${DKZ_PHP_VERSION_INSTALL:-0} / ANGULAR=${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}"
log "##########################################################################"

if [[ "$DKZ_ENV" != "DEV" && "$DKZ_ENV" != "PROD" ]]; then
    log "ERROR: DKZ_ENV is '${DKZ_ENV}' — expected DEV or PROD. Aborting."
    exit 1
fi

# -----------------------------------------------------------------------------
# Nginx
# -----------------------------------------------------------------------------

log "### Nginx"

# Configure Basic Access Authentication for main domain and secondary domains (DKZ_DOMAINS)
_domain_confs=("/etc/nginx/sites-available/${DKZ_DOMAIN}.conf")
if [[ -n "${DKZ_DOMAINS:-}" ]]; then
    IFS=',' read -ra _secondary_domains <<< "${DKZ_DOMAINS}"
    for _secondary in "${_secondary_domains[@]}"; do
        _secondary="${_secondary// /}"
        [[ -n "$_secondary" && -f "/etc/nginx/sites-available/${_secondary}.conf" ]] && _domain_confs+=("/etc/nginx/sites-available/${_secondary}.conf")
    done
fi
if [[ -n "${DKZ_NGINX_BASIC_ACCESS_AUTHENTICATION_USERNAME:-}" && -n "${DKZ_NGINX_BASIC_ACCESS_AUTHENTICATION_PASSWORD:-}" ]]; then
    log "Nginx Basic Access Authentication: enabling for user '${DKZ_NGINX_BASIC_ACCESS_AUTHENTICATION_USERNAME}'"
    echo "${DKZ_NGINX_BASIC_ACCESS_AUTHENTICATION_USERNAME}:$(openssl passwd -apr1 "${DKZ_NGINX_BASIC_ACCESS_AUTHENTICATION_PASSWORD}")" > "/etc/nginx/.htpasswd-${DKZ_DOMAIN}"
    chmod 644 "/etc/nginx/.htpasswd-${DKZ_DOMAIN}"
    for _conf in "${_domain_confs[@]}"; do
        grep -q "#NGINX_BASIC_AUTH_PLACEHOLDER#" "$_conf" || continue
        sed -i "s|    #NGINX_BASIC_AUTH_PLACEHOLDER#|    auth_basic \"Restricted\";\n    auth_basic_user_file /etc/nginx/.htpasswd-${DKZ_DOMAIN};|" "$_conf"
    done
else
    log "Nginx Basic Access Authentication: disabled (no credentials set)"
    for _conf in "${_domain_confs[@]}"; do
        sed -i "/    #NGINX_BASIC_AUTH_PLACEHOLDER#/d" "$_conf"
    done
fi

if [[ "$DKZ_ENV" == "PROD" ]]; then
    # Configure Adminer Basic Access Authentication (scoped to adminer.${DKZ_DOMAIN} only)
    _adminer_conf="/etc/nginx/sites-available/adminer.${DKZ_DOMAIN}.conf"
    if [[ -n "${DKZ_ADMINER_PASSWORD:-}" && -f "$_adminer_conf" ]]; then
        log "Nginx Adminer Basic Access Authentication: enabling"
        echo "adminer:$(openssl passwd -apr1 "${DKZ_ADMINER_PASSWORD}")" > "/etc/nginx/.htpasswd-adminer.${DKZ_DOMAIN}"
        chmod 644 "/etc/nginx/.htpasswd-adminer.${DKZ_DOMAIN}"
        sed -i "s|    #NGINX_ADMINER_AUTH_PLACEHOLDER#|    auth_basic \"Adminer\";\n    auth_basic_user_file /etc/nginx/.htpasswd-adminer.${DKZ_DOMAIN};|" "$_adminer_conf"
    elif [[ -f "$_adminer_conf" ]]; then
        log "Nginx Adminer Basic Access Authentication: disabled (DKZ_ADMINER_PASSWORD not set)"
        sed -i "/    #NGINX_ADMINER_AUTH_PLACEHOLDER#/d" "$_adminer_conf"
    fi
fi

if [[ -f /etc/nginx/sites-available/.gitignore ]]; then
    log "Deleting /etc/nginx/sites-available/.gitignore"
    rm -f /etc/nginx/sites-available/.gitignore
fi

log "Starting nginx ..."
supervisorctl start nginx >> "$_LIB_LOG" 2>&1

# -----------------------------------------------------------------------------
# PHP-FPM
# -----------------------------------------------------------------------------

if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" != "0" ]]; then
    log "### PHP-FPM"
    update_php_ini
    service "php${DKZ_PHP_VERSION_INSTALL}-fpm" start >> "$_LIB_LOG" 2>&1 && log "PHP-FPM ${DKZ_PHP_VERSION_INSTALL} started" || log "WARNING: PHP-FPM ${DKZ_PHP_VERSION_INSTALL} start failed"
fi

# -----------------------------------------------------------------------------
# PostgreSQL
# -----------------------------------------------------------------------------

if [[ "${DKZ_POSTGRESQL_VERSION_INSTALL:-0}" != "0" ]]; then
    log "### PostgreSQL"
    service postgresql start >> "$_LIB_LOG" 2>&1 && log "PostgreSQL started" || log "WARNING: PostgreSQL start failed"
fi

# -----------------------------------------------------------------------------
# MySQL
# -----------------------------------------------------------------------------

if [[ "${DKZ_MYSQL_VERSION_INSTALL:-0}" != "0" ]]; then
    log "### MySQL"
    # TODO: wait for mysql + import backup if database is empty
fi

# -----------------------------------------------------------------------------
# Symfony — DEV: populate the vendor/ named volume via composer install.
# vendor/ is isolated in a named Docker volume (not from the host) for
# performance — composer install must run inside the container on every start.
# -----------------------------------------------------------------------------

if [[ "$DKZ_ENV" == "DEV" && "${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" != "0" ]]; then
    log "### Symfony DEV: composer install"

    if [[ ! -f "/srv/${DKZ_DOMAIN}/composer.json" ]]; then
        log "WARNING: /srv/${DKZ_DOMAIN}/composer.json not found — skipping composer install"
    else
        cd "/srv/${DKZ_DOMAIN}" || { log "ERROR: cannot cd to /srv/${DKZ_DOMAIN}/"; exit 1; }

        APP_ENV=dev composer install --working-dir="/srv/${DKZ_DOMAIN}" >> "$_LIB_LOG" 2>&1 \
            && log "composer install done" || log "WARNING: composer install failed"

        APP_ENV=dev composer dump-autoload --optimize --working-dir="/srv/${DKZ_DOMAIN}" >> "$_LIB_LOG" 2>&1 \
            && log "composer dump-autoload done" || log "WARNING: composer dump-autoload failed"

        APP_ENV=dev php "/srv/${DKZ_DOMAIN}/bin/console" cache:clear --no-warmup >> "$_LIB_LOG" 2>&1 \
            && log "cache:clear done" || log "WARNING: cache:clear failed"

        symfony_run_migrations

        chown -R www-data:www-data "/srv/${DKZ_DOMAIN}/var/" 2>/dev/null || true
    fi
fi

# -----------------------------------------------------------------------------
# Angular / NodeJS
# -----------------------------------------------------------------------------

if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
    log "### Angular / NodeJS"

    # Load nvm so npm is available (supervisord does not source /etc/profile.d/)
    export NVM_DIR="/root/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

    _angular_dir="/srv/${DKZ_DOMAIN}"

    if [[ ! -d "$_angular_dir" ]]; then
        log "WARNING: ${_angular_dir} not found — skipping Angular setup"
    elif ! command -v npm &>/dev/null; then
        log "WARNING: npm not found — skipping npm install (is DKZ_NODEJS_INSTALL=1?)"
    else
        cd "$_angular_dir" || { log "ERROR: cannot cd to ${_angular_dir}"; exit 1; }

        log "Running npm install ..."
        npm install >> "$_LIB_LOG" 2>&1
        log "npm install done."

        if [[ "$DKZ_ENV" != "DEV" ]]; then
            log "PROD: running npm run build ..."
            npm run build >> "$_LIB_LOG" 2>&1
            log "npm run build done."
        fi
    fi
fi

# -----------------------------------------------------------------------------
# Claude Code skills
# -----------------------------------------------------------------------------

log "### Claude Code skills"

# Install a Claude Code skill from a git repository using sparse-checkout.
# Usage: _install_claude_skill <repo_url> <source_path>
# Example: _install_claude_skill https://github.com/anthropics/skills.git skills/skill-creator
# Destination is derived from the last component of <source_path>:
#   /srv/${DKZ_DOMAIN}/.claude/skills/<skill_name>/
_install_claude_skill() {
    local _repo_url="$1"
    local _source_path="$2"
    local _skill_name="${_source_path##*/}"
    local _dest_dir="/srv/${DKZ_DOMAIN}/.claude/skills/${_skill_name}"

    if [[ -d "$_dest_dir" ]]; then
        log "Claude Code ${_skill_name} already installed — skipping"
        return 0
    fi

    log "Installing Claude Code ${_skill_name} ..."
    local _tmp
    _tmp=$(mktemp -d)
    if git clone --no-checkout --depth=1 "$_repo_url" "$_tmp" >> "$_LIB_LOG" 2>&1; then
        git -C "$_tmp" sparse-checkout init --cone >> "$_LIB_LOG" 2>&1
        git -C "$_tmp" sparse-checkout set "$_source_path" >> "$_LIB_LOG" 2>&1
        git -C "$_tmp" checkout main >> "$_LIB_LOG" 2>&1
        mkdir -p "$_dest_dir"
        cp -r "$_tmp/${_source_path}/." "$_dest_dir/"
        log "Claude Code ${_skill_name} installed."
    else
        log "WARNING: Failed to clone ${_repo_url} — ${_skill_name} not installed"
    fi
    rm -rf "$_tmp"
}

_install_claude_skill https://github.com/anthropics/skills.git skills/skill-creator
_install_claude_skill https://github.com/anthropics/skills.git skills/frontend-design
_install_claude_skill https://github.com/Dammyjay93/interface-design.git .claude/skills/interface-design

if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" != "0" ]]; then
    _install_claude_skill https://github.com/affaan-m/everything-claude-code.git skills/api-design
fi

if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
    _install_claude_skill https://github.com/angular/skills.git angular-new-app
    _install_claude_skill https://github.com/angular/skills.git angular-developer
fi

if [[ "${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" != "0" ]]; then
    _install_claude_skill https://github.com/MakFly/superpowers-symfony skills/doctrine-transactions
    _install_claude_skill https://github.com/MakFly/superpowers-symfony skills/interfaces-and-autowiring
    _install_claude_skill https://github.com/MakFly/superpowers-symfony skills/rate-limiting
    _install_claude_skill https://github.com/MakFly/superpowers-symfony skills/symfony-scheduler
fi

if [[ "${DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL:-0}" != "0" ]]; then
    _install_claude_skill https://github.com/MakFly/superpowers-symfony skills/api-platform-filters
    _install_claude_skill https://github.com/MakFly/superpowers-symfony skills/api-platform-security
    _install_claude_skill https://github.com/MakFly/superpowers-symfony skills/api-platform-serialization
    _install_claude_skill https://github.com/MakFly/superpowers-symfony skills/api-platform-tests
    _install_claude_skill https://github.com/MakFly/superpowers-symfony skills/api-platform-versioning
fi

# -----------------------------------------------------------------------------
# Cron
# -----------------------------------------------------------------------------

log "### Cron"
sync_crond
install_crontab
/etc/init.d/cron start >> "$_LIB_LOG" 2>&1 || log "WARNING: cron start failed (may not be installed)"

# -----------------------------------------------------------------------------

log "### Booting done."

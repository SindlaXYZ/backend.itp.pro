#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# lib.sh — Shared utilities for container scripts.
# Usage: source /srv/${DKZ_DOMAIN}/.docker/container/scripts/lib.sh
#
# Provides:
#   - ANSI color variables (CRED, CGREEN, CYELLOW, CDEF, …)
#   - log()            — timestamped logging to per-script log files
#   - sync_crond()     — copy .docker/container/etc/cron.d/* → /etc/cron.d/
#   - install_crontab()— copy project cron.tab → /etc/cron.d/crontab
#
# log() writes to:
#   /srv/${DKZ_DOMAIN}/.docker/.logs/<caller-name>/<Y-m-d>.log
# where <caller-name> is the basename of the entry-point script (without .sh).
# Example: sourced from boot.sh      → .logs/boot/2026-03-12.log
#          sourced from boot-init.sh → .logs/boot-init/2026-03-12.log
#
# Log directory is created and the previous log rotated on the first log() call.
# -----------------------------------------------------------------------------

# =============================================================================
# ANSI color variables
# =============================================================================

source /srv/${DKZ_DOMAIN}/.docker/container/scripts/colors.sh

_LIB_SCRIPT_NAME=$(basename "$0" .sh)
_LIB_LOG_DIR="/srv/${DKZ_DOMAIN}/.docker/.logs/${_LIB_SCRIPT_NAME}"
_LIB_LOG="${_LIB_LOG_DIR}/$(date +%Y-%m-%d).log"
_LIB_LOG_INITIALIZED=false

_log_init() {
    if [[ "$_LIB_LOG_INITIALIZED" == false ]]; then
        mkdir -p "$_LIB_LOG_DIR"
        if [[ -f "$_LIB_LOG" ]]; then
            mv "$_LIB_LOG" "${_LIB_LOG}-$(date +%H%M%S)"
        fi
        _LIB_LOG_INITIALIZED=true
    fi
}

log() {
    _log_init
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$_LIB_LOG"
}

# =============================================================================
# sync_crond — Copy infrastructure cron files from .docker/container/etc/cron.d/
# to /etc/cron.d/. Called from boot.sh on every container start.
# Required before cron starts so that the self-copy mechanism in cron.d/sync
# can bootstrap itself — without this initial copy, nothing runs.
# =============================================================================

sync_crond() {
    local _src="/srv/${DKZ_DOMAIN}/.docker/container/etc/cron.d"
    if [[ -d "$_src" ]]; then
        # Copy only extension-less files — cron ignores files with dots in the name (e.g. .sh)
        find "$_src" -maxdepth 1 -type f ! -name "*.*" -exec cp -u {} /etc/cron.d/ \;
        chmod 0644 /etc/cron.d/* 2>/dev/null || true
        log "Synced ${_src}/ (extension-less files) → /etc/cron.d/"
    else
        log "WARNING: ${_src} not found — infrastructure cron jobs will not be installed"
    fi
}

# =============================================================================
# install_crontab — Copy project cron.tab to /etc/cron.d/crontab.
# Called from boot.sh (every start) and sync.sh (DEV only, every 2 min).
# Source file per project type:
#   type 1 (PHP/Symfony) → .docker/stubs/symfony/v8.0/cron.tab (skeleton)
#   type 2 (Angular)     → .docker/stubs/angular/v21/cron.tab   (skeleton)
# Both stubs contain a CRONTAB CHECKER entry that writes a timestamp to
# /srv/${DKZ_DOMAIN}/.docker/.logs/crontab/cron.checker every minute —
# used by motd.sh to display when cron last ran.
# =============================================================================

install_crontab() {
    local _src="/srv/${DKZ_DOMAIN}/cron.tab"
    local _dest="/etc/cron.d/crontab"
    if [[ -f "$_src" ]]; then
        cp -f "$_src" "$_dest"
        chmod 0644 "$_dest"
        log "Installed ${_src} → ${_dest}"
    else
        log "WARNING: ${_src} not found — application cron jobs will not run"
    fi
}

# =============================================================================
# update_php_ini — Apply environment-specific settings to php.ini and pool config.
# Called from boot.sh on every container start, before PHP-FPM starts.
# No-op when DKZ_PHP_VERSION_INSTALL == 0.
#
# Reads DKZ_* vars: DKZ_PHP_VERSION_INSTALL, DKZ_ENV, DKZ_DOMAIN,
#   DKZ_PHP_MAX_EXECUTION_TIME, DKZ_PHP_MAX_INPUT_VARS, DKZ_PHP_MEMORY_LIMIT,
#   DKZ_PHP_CLI_MEMORY_LIMIT, DKZ_PHP_PRELOAD
# =============================================================================

update_php_ini() {
    [[ "${DKZ_PHP_VERSION_INSTALL:-0}" == "0" ]] && return

    local _ver="${DKZ_PHP_VERSION_INSTALL}"
    local _cli_ini="/etc/php/${_ver}/cli/php.ini"
    local _fpm_ini="/etc/php/${_ver}/fpm/php.ini"
    local _fpm_pool="/etc/php/${_ver}/fpm/pool.d/www.conf"
    local _log_fpm="/srv/${DKZ_DOMAIN}/.docker/.logs/phpfpm/php_fpm_errors.log"
    local _log_cli="/srv/${DKZ_DOMAIN}/.docker/.logs/phpfpm/php_cli_errors.log"
    local _log_opcache="/srv/${DKZ_DOMAIN}/.docker/.logs/phpfpm/php_opcache_errors.log"
    local _session_path="/tmp/${DKZ_DOMAIN}/sessions"

    mkdir -p "/srv/${DKZ_DOMAIN}/.docker/.logs/phpfpm" "$_session_path"

    local _error_display _error_reporting _opcache_revalidate_freq _opcache_validate_timestamp
    if [[ "$DKZ_ENV" == "DEV" ]]; then
        _error_display="On"
        _error_reporting="E_ALL"
        _opcache_revalidate_freq="0"
        _opcache_validate_timestamp="1"
    else
        _error_display="Off"
        _error_reporting="E_ALL \& ~E_DEPRECATED \& ~E_STRICT"
        _opcache_revalidate_freq="60"
        _opcache_validate_timestamp="0"
    fi

    log "update_php_ini: applying settings for PHP ${_ver} (ENV=${DKZ_ENV})"

    # FPM & CLI — common settings
    sed -i \
        -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' \
        -e 's/^short_open_tag = Off/short_open_tag = On/g' \
        -e 's/;date.timezone =/date.timezone = UTC/g' \
        -e "s/^display_errors =.*/display_errors = ${_error_display}/g" \
        -e "s/^error_reporting =.*/error_reporting = ${_error_reporting}/g" \
        -e 's/^expose_php = On/expose_php = Off/g' \
        -e 's/;realpath_cache_size =.*/realpath_cache_size = 4096k/g' \
        -e "s|;error_log = php_errors.log|error_log = ${_log_fpm}|g" \
        -e 's/^post_max_size =.*/post_max_size = 100M/g' \
        -e 's/^upload_max_filesize =.*/upload_max_filesize = 100M/g' \
        -e "s#;session.save_path =.*#session.save_path = \"${_session_path}\"#g" \
        -e "s#session.save_path =.*#session.save_path = \"${_session_path}\"#g" \
        -e 's/^session.gc_probability =.*/session.gc_probability = 0/g' \
        -e 's/^;realpath_cache_ttl =.*/realpath_cache_ttl = 600/g' \
        -e 's/^realpath_cache_ttl =.*/realpath_cache_ttl = 600/g' \
        -e "s/^max_execution_time[ ]*=.*/max_execution_time = ${DKZ_PHP_MAX_EXECUTION_TIME}/g" \
        -e "s/^memory_limit[ ]*=.*/memory_limit = ${DKZ_PHP_MEMORY_LIMIT}/g" \
        "$_cli_ini" "$_fpm_ini"

    # FPM & CLI — max_input_vars (handles commented and uncommented variants)
    sed -Ei "s#^;?max_input_vars\s*=.*#max_input_vars = ${DKZ_PHP_MAX_INPUT_VARS}#g" "$_cli_ini" "$_fpm_ini"

    # FPM only — opcache settings
    sed -i \
        -e 's/^;opcache.enable[ ]*=.*/opcache.enable = 1/g' \
        -e 's/^opcache.enable[ ]*=.*/opcache.enable = 1/g' \
        -e 's/^;opcache.enable_cli[ ]*=.*/opcache.enable_cli = 0/g' \
        -e 's/^;opcache.memory_consumption[ ]*=.*/opcache.memory_consumption = 512/g' \
        -e 's/^opcache.memory_consumption[ ]*=.*/opcache.memory_consumption = 512/g' \
        -e 's/^;opcache.max_accelerated_files[ ]*=.*/opcache.max_accelerated_files = 20000/g' \
        -e 's/^opcache.max_accelerated_files[ ]*=.*/opcache.max_accelerated_files = 20000/g' \
        -e "s|^;opcache.error_log[ ]*=.*|opcache.error_log = ${_log_opcache}|g" \
        -e "s|^;opcache.revalidate_freq[ ]*=.*|opcache.revalidate_freq = ${_opcache_revalidate_freq}|g" \
        -e "s|^opcache.revalidate_freq[ ]*=.*|opcache.revalidate_freq = ${_opcache_revalidate_freq}|g" \
        -e "s|^;opcache.validate_timestamps[ ]*=.*|opcache.validate_timestamps = ${_opcache_validate_timestamp}|g" \
        -e "s|^opcache.validate_timestamps[ ]*=.*|opcache.validate_timestamps = ${_opcache_validate_timestamp}|g" \
        "$_fpm_ini"

    # FPM only — JIT (append if not already present)
    grep -q "^opcache.jit_buffer_size=" "$_fpm_ini" || printf "\nopcache.jit_buffer_size=512M\n" >> "$_fpm_ini"
    grep -q "^opcache.jit=" "$_fpm_ini"             || printf "\nopcache.jit=tracing\n"          >> "$_fpm_ini"

    # FPM conf.d/10-opcache.ini — enforce JIT if file exists
    local _opcache_ini="/etc/php/${_ver}/fpm/conf.d/10-opcache.ini"
    [[ -f "$_opcache_ini" ]] && sed -i 's/^opcache.jit.*=.*/opcache.jit=tracing/g' "$_opcache_ini"

    # CLI only — separate error_log and CLI memory limit
    sed -i \
        -e "s|error_log = ${_log_fpm}|error_log = ${_log_cli}|g" \
        -e "s/^memory_limit[ ]*=.*/memory_limit = ${DKZ_PHP_CLI_MEMORY_LIMIT}/g" \
        "$_cli_ini"

    # DEV only — disable xdebug for FPM, enable coverage mode for CLI
    if [[ "$DKZ_ENV" == "DEV" ]]; then
        if ! grep -q "# Disable XDebug" "$_fpm_ini"; then
            printf "\n\n# Disable XDebug\nxdebug.remote_autostart=0\nxdebug.remote_enable=0\nxdebug.default_enable=0\nprofiler_enable=0\n" >> "$_fpm_ini"
        fi
        local _xdebug_ini="/etc/php/${_ver}/fpm/conf.d/20-xdebug.ini"
        [[ -f "$_xdebug_ini" ]] && mv "$_xdebug_ini" "${_xdebug_ini}.bak"
        grep -q "xdebug.mode" "$_cli_ini" || printf "\nxdebug.mode=coverage\n" >> "$_cli_ini"
    fi

    # fpm/pool.d/www.conf — TCP listen + permissions (idempotent; also applied at build time)
    sed -i \
        -e 's/listen = .*/listen = 127.0.0.1:9000/g' \
        -e 's/;listen.owner/listen.owner/g' \
        -e 's/;listen.group/listen.group/g' \
        -e 's/;listen.mode.*/listen.mode = 0660/g' \
        -e 's/^listen.acl_users/;listen.acl_users/g' \
        -e 's/^listen.acl_groups/;listen.acl_groups/g' \
        "$_fpm_pool"

    # PROD only — opcache preload (if DKZ_PHP_PRELOAD is set and file exists)
    if [[ "$DKZ_ENV" == "PROD" ]] && [[ -n "$DKZ_PHP_PRELOAD" ]] && [[ -f "$DKZ_PHP_PRELOAD" ]]; then
        sed -i \
            -e 's#;opcache.preload_user[ ]*=.*#opcache.preload_user = www-data#g' \
            -e "s#;opcache.preload[ ]*=.*#opcache.preload = ${DKZ_PHP_PRELOAD}#g" \
            -e 's#;opcache.validate_timestamps[ ]*=.*#opcache.validate_timestamps = 0#g' \
            "$_fpm_ini"
    fi

    log "update_php_ini: done"
}

# =============================================================================
# dotENV — Insert a new KEY=VALUE line into a .env file, adjacent to an
# existing key. Idempotent: skips silently if the new key already exists.
#
# Usage:
#   dotENV FILE_PATH (before|after|-1|1) EXISTING_KEY NEW_KEY_VALUE
#
# Examples:
#   dotENV "/srv/${DKZ_DOMAIN}/.env" after  DATABASE_URL "AUDIT_DATABASE_URL=pgsql://..."
#   dotENV "/srv/${DKZ_DOMAIN}/.env" before DATABASE_URL "AUDIT_DATABASE_URL=pgsql://..."
#
# Arguments:
#   $1  Absolute path to the .env file
#   $2  Position: "after" or "1"  → insert on the line below EXISTING_KEY
#                "before" or "-1" → insert on the line above EXISTING_KEY
#   $3  Anchor key name (no "=" suffix) — the line matched is "^KEY="
#   $4  Full new key=value string to insert
# =============================================================================
dotENV() {
    local _file="$1"
    local _position="$2"
    local _anchor_key="$3"
    local _new_kv="$4"

    if [[ ! -f "$_file" ]]; then
        log "dotENV: file not found: ${_file}"
        return 1
    fi

    # Extract key from "KEY=value"
    local _new_key="${_new_kv%%=*}"

    # Idempotency: skip if the new key is already present
    if grep -q "^${_new_key}=" "$_file"; then
        log "dotENV: ${_new_key} already present in ${_file} — skipping"
        return 0
    fi

    # Verify anchor key exists
    if ! grep -q "^${_anchor_key}=" "$_file"; then
        log "dotENV: anchor key '${_anchor_key}' not found in ${_file}"
        return 1
    fi

    local _tmp="${_file}.dotenv_tmp"

    # awk inserts only on the FIRST match of the anchor key
    awk -v anchor="^${_anchor_key}=" -v new_kv="${_new_kv}" -v pos="${_position}" '
        !inserted && $0 ~ anchor {
            if (pos == "after" || pos == "1") { print; print new_kv }
            else { print new_kv; print }
            inserted = 1
            next
        }
        { print }
    ' "$_file" > "$_tmp" && mv "$_tmp" "$_file"

    log "dotENV: inserted '${_new_key}' ${_position} '${_anchor_key}' in ${_file}"
}

# symfony_run_migrations() — Syncs Doctrine metadata storage and runs pending migrations.
# No-op when doctrine/doctrine-migrations-bundle is not in composer.json.
symfony_run_migrations() {
    if ! grep -q '"doctrine/doctrine-migrations-bundle"' "/srv/${DKZ_DOMAIN}/composer.json" 2>/dev/null; then
        log "doctrine/doctrine-migrations-bundle not in composer.json — skipping migrations"
        return 0
    fi
    log "Syncing Doctrine metadata storage ..."
    php "/srv/${DKZ_DOMAIN}/bin/console" doctrine:migrations:sync-metadata-storage >> "$_LIB_LOG" 2>&1
    log "Running Doctrine migrations ..."
    php "/srv/${DKZ_DOMAIN}/bin/console" doctrine:migrations:migrate -n >> "$_LIB_LOG" 2>&1
    log "Doctrine migrations done."
}

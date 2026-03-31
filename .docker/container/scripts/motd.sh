#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# motd.sh — Message of the Day.
#
# Sourced by /etc/bash.bashrc on every interactive shell start (i.e., on
# container connect). Also callable on demand via the 'motd' alias.
#
# Displays: system info, service statuses, and a per-project-type cheatsheet.
# Defines: shell aliases available for the duration of the session.
#
# Sourced at runtime from /srv/${DKZ_DOMAIN}/.docker/container/scripts/motd.sh
# (volume-mounted in DEV; git-cloned in PROD). NOT baked into /etc/dockraft/scripts/.
# -----------------------------------------------------------------------------

source /srv/${DKZ_DOMAIN}/.docker/container/scripts/lib.sh

# =============================================================================
# Aliases
# =============================================================================

alias ll='ls -alh --time-style="+%Y-%m-%d %T" --color=auto --group-directories-first'
alias llt='ls -altr --time-style="+%Y-%m-%d %T" --color=auto --group-directories-first'
alias motd='clear && bash /srv/${DKZ_DOMAIN}/.docker/container/scripts/motd.sh'
alias dkzenv='printenv -0 | sort -z | tr "\0" "\n" | grep "DKZ_"'
alias ss='service --status-all 2>&1'

# Symfony aliases — active when Symfony is installed
if [[ "${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" != "0" ]]; then
    # Symfony console shortcut functions: dbd, dbm, dbv, dbs, dbl, symabout, symdeps, symenvs, symroutes, symroute, symdotenv, symparameters, sdepres
    source /srv/${DKZ_DOMAIN}/.docker/container/scripts/symfony.sh
fi

# deploy alias — PROD only, for PHP/Symfony or Angular projects
if [[ "$DKZ_ENV" == "PROD" ]] && [[ "${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" != "0" || "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
    alias deploy="bash /srv/${DKZ_DOMAIN}/.docker/container/scripts/deploy.sh"
fi

# =============================================================================
# _proc_running — Returns 0 if a process matching $1 is running
# =============================================================================

_proc_running() {
    local name="$1"
    local me
    me=$(basename "$0")

    if command -v ps &>/dev/null; then
        ps ax | grep -v grep | grep -v "$me" | grep -q "$name"
    elif command -v pgrep &>/dev/null; then
        pgrep -f "$name" &>/dev/null
    else
        local f
        for f in /proc/[0-9]*/cmdline; do
            tr '\0' ' ' < "$f" 2>/dev/null | grep -q "$name" && return 0
        done
        return 1
    fi
}

# =============================================================================
# _check_composer_platform_php — Warn if composer.json .config.platform.php != installed PHP
# =============================================================================

_check_composer_platform_php() {
    if ! command -v php &>/dev/null; then
        return 0
    fi
    if ! command -v jq &>/dev/null; then
        return 0
    fi
    local _composer_json="/srv/${DKZ_DOMAIN}/composer.json"
    if [ ! -f "$_composer_json" ]; then
        return 0
    fi
    local _composer_php_ver_abc _composer_php_ver_ab _php_ver_ab
    _composer_php_ver_abc=$(jq --raw-output '.config.platform.php // empty' "$_composer_json")
    if [ -z "$_composer_php_ver_abc" ]; then
        return 0
    fi
    _composer_php_ver_ab=$(echo "$_composer_php_ver_abc" | grep -Eo '([0-9]+)\.(\.?[0-9]+)*' | head -1)
    _php_ver_ab=$(php -v | grep ^PHP | cut -d' ' -f2 | cut -d '.' -f 1,2)
    if [ "$_composer_php_ver_ab" != "$_php_ver_ab" ]; then
        echo -e "${CYELLOW}PHP version ${_php_ver_ab} != ${_composer_php_ver_ab} composer > .config.platform.php different versions${CDEF}"
    fi
}

# =============================================================================
# dockraft — Update dockraft files from the upstream git repository (DEV only).
#
# Clones the dockraft remote (read from .docker/.git/config) into a temp dir,
# copies updated files into .docker/, syncs boot-init.sh to /etc/dockraft/scripts/
# (all other scripts are live in the project directory), and patches .docker/.env with the current
# DKZ_* runtime values so the template reflects the project's state.
# =============================================================================

dockraft() {
    if [[ "$DKZ_ENV" != "DEV" ]]; then
        echo -e "${CRED}dockraft is available only in the DEV environment.${CDEF}"
        return 1
    fi

    local project_dir="/srv/${DKZ_DOMAIN}"
    local dockraft_dir="${project_dir}/.docker"

    # Read GitHub token from /root/.dockraft-token (written at build time via BuildKit secret).
    # If missing or empty, prompt the user once.
    local githubPersonalToken=""
    if [[ -f /root/.dockraft-token && -s /root/.dockraft-token ]]; then
        githubPersonalToken=$(cat /root/.dockraft-token)
    fi
    if [[ -z "$githubPersonalToken" ]]; then
        echo -e "${CYELLOW}GitHub Personal Access Token (required to clone dockraft):${CDEF}"
        read -r -s githubPersonalToken
        echo ""
    fi
    if [[ -z "$githubPersonalToken" || "$githubPersonalToken" == "NOT SET" ]]; then
        echo -e "${CRED}dockraft: no token provided — cannot clone private repository.${CDEF}"
        return 1
    fi
    if echo "$githubPersonalToken" | grep -qP '[^\x00-\x7F]'; then
        echo -e "${CRED}dockraft: token contains non-ASCII characters.${CDEF}"
        return 1
    fi

    local clone_url="https://SindlaXYZ:${githubPersonalToken}@github.com/SindlaXYZ/dockraft.git"

    local random tmp_dir
    random=$(shuf -i 10000-99000 -n 1)
    tmp_dir="/tmp/dockraft-${random}"

    echo -e "\n${CYELLOW}Cloning dockraft ...${CDEF}"
    git clone --depth=1 "${clone_url}" "${tmp_dir}"

    if [[ $? -ne 0 ]]; then
        echo -e "${CRED}dockraft: clone failed.${CDEF}"
        rm -rf "${tmp_dir}"
        return 1
    fi

    echo -e "${CYELLOW}Updating .docker/container/ ...${CDEF}"
    cp -fru "${tmp_dir}/.docker/container/." "${dockraft_dir}/container/"

    echo -e "${CYELLOW}Updating .docker/host/ ...${CDEF}"
    cp -fru "${tmp_dir}/.docker/host/." "${dockraft_dir}/host/"

    # Compare .docker/.env keys between upstream and current — no overwrite
    echo -e "${CYELLOW}Comparing .docker/.env keys (upstream vs project) ...${CDEF}"
    local _upstream_keys _current_keys _missing_in_current _missing_in_upstream
    _upstream_keys=$(grep -E '^[A-Z_][A-Z_0-9]*=' "${tmp_dir}/.docker/.env" | cut -d'=' -f1 | sort)
    _current_keys=$(grep -E '^[A-Z_][A-Z_0-9]*=' "${dockraft_dir}/.env" | cut -d'=' -f1 | sort)
    _missing_in_current=$(comm -23 <(echo "$_upstream_keys") <(echo "$_current_keys"))
    _missing_in_upstream=$(comm -13 <(echo "$_upstream_keys") <(echo "$_current_keys"))
    if [[ -n "$_missing_in_current" ]]; then
        echo -e "${CRED}Keys in upstream .env but missing from project .env (add manually):${CDEF}"
        while IFS= read -r _k; do echo -e "  ${CRED}+ ${_k}${CDEF}"; done <<< "$_missing_in_current"
    fi
    if [[ -n "$_missing_in_upstream" ]]; then
        echo -e "${CRED}Keys in project .env but missing from upstream .env (may be obsolete):${CDEF}"
        while IFS= read -r _k; do echo -e "  ${CRED}- ${_k}${CDEF}"; done <<< "$_missing_in_upstream"
    fi
    if [[ -z "$_missing_in_current" && -z "$_missing_in_upstream" ]]; then
        echo -e "${CGREEN}.docker/.env keys are in sync with upstream${CDEF}"
    fi

    echo -e "${CYELLOW}Updating Dockerfile and Dockerfile.sh ...${CDEF}"
    cp -f "${tmp_dir}/.docker/Dockerfile" "${dockraft_dir}/Dockerfile"
    cp -f "${tmp_dir}/.docker/Dockerfile.sh" "${dockraft_dir}/Dockerfile.sh"

    # Update .editorconfig from the clone root
    if [[ -f "${tmp_dir}/.editorconfig" ]]; then
        echo -e "${CYELLOW}Updating .editorconfig ...${CDEF}"
        cp -f "${tmp_dir}/.editorconfig" "${project_dir}/.editorconfig"
    fi

    # Copy cron.tab from stubs if not yet present in the project
    if [[ ! -f "${project_dir}/cron.tab" ]]; then
        echo -e "${CYELLOW}Updating cron.tab from stubs ...${CDEF}"
        if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" != "0" ]]; then
            cp -f "${tmp_dir}/.docker/stubs/symfony/v8.0/cron.tab" "${project_dir}/cron.tab"
        elif [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
            cp -f "${tmp_dir}/.docker/stubs/angular/v21/cron.tab" "${project_dir}/cron.tab"
        fi
    fi

    # Sync boot-init.sh to its baked path (the only script that lives in /etc/dockraft/scripts/).
    # All other scripts are already live in the project directory after the cp -fru steps above.
    echo -e "${CYELLOW}Syncing boot-init.sh ...${CDEF}"
    cp -f "${dockraft_dir}/container/scripts/boot-init.sh" /etc/dockraft/scripts/boot-init.sh
    chmod +x /etc/dockraft/scripts/boot-init.sh

    # Sync supervisor base config and program configs
    echo -e "${CYELLOW}Syncing supervisord programs ...${CDEF}"
    cp -f  "${dockraft_dir}/container/etc/supervisor/conf.d/supervisord.conf" /etc/supervisor/conf.d/supervisord.conf
    cp -fru "${tmp_dir}/.docker/container/etc/supervisor/program/." "${dockraft_dir}/container/etc/supervisor/program/"

    # Reload supervisord config: apply program additions/removals without restarting unchanged programs.
    # supervisorctl update internally re-reads all config files, then starts/stops as needed.
    if pgrep -x supervisord &>/dev/null; then
        supervisorctl update 2>/dev/null || echo -e "${CYELLOW}supervisorctl update failed — run it manually after the shell reloads.${CDEF}"
    else
        echo -e "${CYELLOW}supervisord process not found.${CDEF}"
    fi

    # Patch .docker/.env with current DKZ_* runtime values
    # Passwords and secrets are intentionally excluded.
    echo -e "${CYELLOW}Patching .docker/.env with current DKZ_* values ...${CDEF}"
    local _patch_vars=(
        "DKZ_ENV" "DKZ_NODEJS_ANGULAR_VERSION_INSTALL" "DKZ_RUN_RESTART" "DKZ_DIST" "DKZ_SHARED_MEMORY"
        "DKZ_DOMAIN" "DKZ_NAME" "DKZ_PORT_PREFIX" "DKZ_SHARED_PORTS"
        "DKZ_GIT_REPO_URI" "DKZ_GIT_BRANCH_DEVELOPMENT" "DKZ_GIT_BRANCH_STAGING" "DKZ_GIT_BRANCH_PRODUCTION"
        "DKZ_PHP_VERSION_INSTALL" "DKZ_PHP_SYMFONY_VERSION_INSTALL" "DKZ_PHP_SYMFONY_AURORA_INSTALL" "DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL" "DKZ_PHP_PRELOAD"
        "DKZ_PHP_XDEBUG" "DKZ_PHP_MAX_EXECUTION_TIME" "DKZ_PHP_MAX_INPUT_VARS"
        "DKZ_PHP_MEMORY_LIMIT" "DKZ_PHP_CLI_MEMORY_LIMIT" "DKZ_PHP_RESTART_IF_BAD_DOMAIN_STATUS_CODE"
        "DKZ_POSTGRESQL_VERSION_INSTALL" "DKZ_POSTGRESQL_USERNAME" "DKZ_POSTGRESQL_DATABASE"
        "DKZ_MYSQL_VERSION_INSTALL" "DKZ_MYSQL_USERNAME" "DKZ_MYSQL_DATABASE"
        "DKZ_CERTBOT_INSTALL" "DKZ_NODEJS_INSTALL" "DKZ_NODEJS_ANGULAR_PORT"
        "DKZ_AI_CODEX_INSTALL" "DKZ_AI_GEMINI_INSTALL" "DKZ_AI_CLAUDE_CODE_INSTALL"
        "DKZ_MEMCACHED_INSTALL" "DKZ_MONGODB_INSTALL" "DKZ_RABBITMQ_INSTALL"
    )

    for _key in "${_patch_vars[@]}"; do
        if [[ -n "${!_key}" ]]; then
            sed -i "s|^${_key}=.*|${_key}=${!_key}|g" "${dockraft_dir}/.env"
        fi
    done

    echo -e "${CGREEN}Done.${CDEF}"
    echo -e "${CYELLOW}Check [git status] for changes.${CDEF}"
    rm -rf "${tmp_dir}"
    sleep 2
    cd "${project_dir}" || true
    source /etc/bash.bashrc
}

separator() {
    echo -e "\n${CCYAN}==================================================================================${CDEF}\n"
}

# =============================================================================
# System info
# =============================================================================

DISTRIBUTION=$(. /etc/os-release && echo "$PRETTY_NAME")
LINUX_KERNEL=$(uname -srm)
HOSTNAME=$(uname -n)
PUBLIC_IP=$(curl --max-time 2 --silent ipinfo.io/ip 2>/dev/null)
[[ -z "$PUBLIC_IP" ]] && PUBLIC_IP="N/A"

if command -v free &>/dev/null; then
    MEMORY_USED=$(free -t -m | grep Total | awk '{print $3" MB";}')
    MEMORY_TOTAL=$(free -t -m | grep "^Mem" | awk '{print $2" MB";}')
    SWAP_USED="$(free -m | tail -n 1 | awk '{print $3}') MB"
else
    MEMORY_USED="N/A"
    MEMORY_TOTAL="N/A"
    SWAP_USED="N/A"
fi

LOAD1=$(awk '{print $1}' /proc/loadavg)
LOAD5=$(awk '{print $2}' /proc/loadavg)
LOAD15=$(awk '{print $3}' /proc/loadavg)

DISK_SRV=$(df -h /srv 2>/dev/null | awk 'NR==2{print $3"/"$2" ("$5" used)"}')
[[ -z "$DISK_SRV" ]] && DISK_SRV="N/A"

DATE_LOCAL=$(date +"%Y-%m-%d %H:%M:%S [%Z %z]")

# =============================================================================
# Git info (PROD only — in DEV the project is volume-mounted so git is live)
# =============================================================================

if [[ "$DKZ_ENV" == "PROD" ]] && command -v git &>/dev/null && git -C "/srv/${DKZ_DOMAIN}/" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    GIT_BRANCH=$(git -C "/srv/${DKZ_DOMAIN}/" branch --show-current 2>/dev/null || echo "N/A")
    GIT_COMMIT=$(TZ=Europe/Bucharest git -C "/srv/${DKZ_DOMAIN}/" log -1 --format="%h %s (%cd)" --date="format-local:%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A")
else
    GIT_BRANCH="N/A"
    GIT_COMMIT="N/A"
fi

# =============================================================================
# Domain URL + HTTP status
# =============================================================================

if [[ "$DKZ_ENV" == "DEV" ]]; then
    DOMAIN_URL="${DKZ_DOMAIN}.localhost:${DKZ_PORT80}"
    _HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://localhost" 2>/dev/null)
else
    DOMAIN_URL="${DKZ_DOMAIN}"
    _HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "https://${DKZ_DOMAIN}" 2>/dev/null)
fi
[[ "$_HTTP_STATUS" == "000" ]] && _HTTP_STATUS="NO CONNECTION"

if [[ "$_HTTP_STATUS" == "200" ]]; then
    DOMAIN_DISPLAY="${CGREEN}${DOMAIN_URL}${CDEF}"
elif [[ "$_HTTP_STATUS" == "NO CONNECTION" ]]; then
    DOMAIN_DISPLAY="${CRED}${DOMAIN_URL} [NO CONNECTION]${CDEF}"
else
    DOMAIN_DISPLAY="${CRED}${DOMAIN_URL} [HTTP ${_HTTP_STATUS:-unreachable}]${CDEF}"
fi

# =============================================================================
# Service status helpers
# =============================================================================

# _svc_uptime() — Returns elapsed time for a running process (ps etime format), or "-" if not running.
# $1: process name pattern passed to pgrep -f
_svc_uptime() {
    local pid
    pid=$(pgrep -f "$1" 2>/dev/null | head -1)
    [[ -z "$pid" ]] && echo "-" && return
    ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ' || echo "-"
}

# _svc_row() — Prints one row in the service status table.
# Strips ANSI codes from $2 before padding to get correct visual width.
# $1: service name  (plain, max ~20 chars)
# $2: status string (may contain ANSI color codes, e.g. "${CGREEN}running${CDEF}")
# $3: version       (plain, e.g. "v8.4.0" or "-")
# $4: info          (may contain ANSI color codes — uptime or "last: X ago")
_svc_row() {
    local name="$1" status_colored="$2" version="${3:--}" info="${4:--}"
    local status_plain
    status_plain=$(printf '%b' "$status_colored" | sed 's/\x1b\[[0-9;]*m//g')
    local col2_pad=$(( 14 - ${#status_plain} ))
    [[ $col2_pad -lt 1 ]] && col2_pad=1
    printf "  %-22s" "$name"
    printf '%b' "$status_colored"
    printf "%*s%-20s  " "$col2_pad" "" "$version"
    printf '%b\n' "$info"
}

# =============================================================================
# Display
# =============================================================================

separator
echo -e " - Date/Time..................: ${DATE_LOCAL}"
echo -e " - Distribution...............: ${DISTRIBUTION}"
echo -e " - Linux kernel...............: ${LINUX_KERNEL}"
echo -e " - Hostname...................: ${HOSTNAME}"
echo -e " - Public IP..................: ${PUBLIC_IP}"
echo -e " - Disk (/srv)................: ${DISK_SRV}"
echo -e " - CPU load (1/5/15 min)......: ${LOAD1}, ${LOAD5}, ${LOAD15}"
echo -e " - Memory used................: ${MEMORY_USED} / ${MEMORY_TOTAL}"
echo -e " - Swap in use................: ${SWAP_USED}"
separator
echo -e " - Domain.....................: $(echo -e "${DOMAIN_DISPLAY}")"
echo -e " - DKZ environment............: ${DKZ_ENV}"
echo -e " - GIT branch.................: ${GIT_BRANCH}"
echo -e " - GIT latest commit..........: ${GIT_COMMIT}"
separator
echo -e "  ${CGREY}$(printf '%-22s%-14s%-20s  %s' 'Service' 'Status' 'Version' 'Uptime / Info')${CDEF}"
echo -e "  ${CGREY}─────────────────────────────────────────────────────────────────────${CDEF}"

# systemd — not a service in Docker; version via systemctl
_systemd_ver=$(systemctl --version 2>/dev/null | head -1 | awk '{print $2}')
if [[ -n "$_systemd_ver" ]]; then
    _systemd_uptime=$(ps -o etime= -p 1 2>/dev/null | tr -d ' ')
    [[ -z "$_systemd_uptime" ]] && _systemd_uptime="-"
    _svc_row "systemd" "${CGREEN}running${CDEF}" "v${_systemd_ver}" "${_systemd_uptime}"
fi

# Supervisor
if _proc_running "supervisord"; then
    _ver=$(supervisord -v 2>/dev/null | grep -oE '[0-9.]+' | head -1)
    _svc_row "Supervisor" "${CGREEN}running${CDEF}" "v${_ver}" "$(_svc_uptime "supervisord")"
else
    _svc_row "Supervisor" "${CRED}stopped${CDEF}"
fi

# Cron
_cron_checker="/srv/${DKZ_DOMAIN}/.docker/.logs/crontab/cron.checker"
_cron_info=""
if [[ -f "$_cron_checker" ]]; then
    _diff=$(( $(date +%s) - $(stat -c %Y "$_cron_checker") ))
    _diff_days=$(( _diff / 86400 ))
    _diff_hours=$(( (_diff % 86400) / 3600 ))
    _diff_minutes=$(( (_diff % 3600) / 60 ))
    if [[ $_diff -lt 65 ]]; then
        _s=$([ $_diff -eq 1 ] && echo second || echo seconds)
        _cron_info="${_diff} ${_s} ago"
    elif [[ $_diff_days -gt 0 ]]; then
        _sd=$([ $_diff_days -eq 1 ] && echo day || echo days)
        _sh=$([ $_diff_hours -eq 1 ] && echo hour || echo hours)
        _cron_info="${CRED}${_diff_days} ${_sd} and ${_diff_hours} ${_sh} ago${CDEF}"
    elif [[ $_diff_hours -gt 0 ]]; then
        _sh=$([ $_diff_hours -eq 1 ] && echo hour || echo hours)
        _sm=$([ $_diff_minutes -eq 1 ] && echo minute || echo minutes)
        _cron_info="${CRED}${_diff_hours} ${_sh} and ${_diff_minutes} ${_sm} ago${CDEF}"
    else
        _sm=$([ $_diff_minutes -eq 1 ] && echo minute || echo minutes)
        _cron_info="${CYELLOW}${_diff_minutes} ${_sm} ago${CDEF}"
    fi
else
    _cron_info="${CRED}checker not found${CDEF}"
fi
if _proc_running "/usr/sbin/cron"; then
    _svc_row "Cron" "${CGREEN}running${CDEF}" "-" "${_cron_info}"
else
    _svc_row "Cron" "${CRED}stopped${CDEF}" "-" "${_cron_info}"
fi

if [[ "${DKZ_NGINX_INSTALL:-0}" == "1" ]]; then
    if _proc_running "nginx"; then
        _ver=$(nginx -v 2>&1 | grep -oE '[0-9.]+' | head -1)
        _svc_row "Nginx" "${CGREEN}running${CDEF}" "v${_ver}" "$(_svc_uptime "nginx")"
    else
        _svc_row "Nginx" "${CRED}stopped${CDEF}"
    fi
fi

if [[ "${DKZ_NODEJS_INSTALL:-0}" == "1" ]]; then
    _ver=$(node --version 2>/dev/null)
    _svc_row "NodeJS" "${CGREEN}installed${CDEF}" "${_ver}" "-"
fi

if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
    _ANG_VER=$(node -e "try{const p=JSON.parse(require('fs').readFileSync('/srv/${DKZ_DOMAIN}/package.json','utf8'));const v=(p.dependencies||{})['@angular/core']||(p.devDependencies||{})['@angular/core']||'';console.log('v'+v.replace(/[\\^~>=< ]/g,'').split('.').slice(0,3).join('.'))}catch(e){}" 2>/dev/null)
    [[ -z "$_ANG_VER" ]] && _ANG_VER="unknown"
    if [[ "$DKZ_ENV" == "DEV" ]]; then
        if _proc_running "ng serve"; then
            _svc_row "Angular" "${CGREEN}running${CDEF}" "${_ANG_VER}" "$(_svc_uptime "ng serve")"
        else
            _svc_row "Angular" "${CYELLOW}not running${CDEF}" "${_ANG_VER}" "run: ng serve --port ${DKZ_NODEJS_ANGULAR_PORT} --host 0.0.0.0"
        fi
    else
        if _proc_running "server.mjs"; then
            _svc_row "Angular" "${CGREEN}running${CDEF}" "${_ANG_VER}" "$(_svc_uptime "server.mjs")"
        else
            _svc_row "Angular" "${CRED}stopped${CDEF}" "${_ANG_VER}"
        fi
    fi
fi

if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" != "0" ]]; then
    if _proc_running "php-fpm"; then
        _ver=$(php -v 2>/dev/null | grep -oE '[0-9.]+' | head -1)
        _svc_row "PHP-FPM" "${CGREEN}running${CDEF}" "v${_ver}" "$(_svc_uptime "php-fpm")"
    else
        _svc_row "PHP-FPM" "${CRED}stopped${CDEF}"
    fi
    _check_composer_platform_php
fi

if [[ "${DKZ_POSTGRESQL_VERSION_INSTALL:-0}" != "0" ]]; then
    if _proc_running "postgres"; then
        _ver=$(pg_config --version 2>/dev/null | grep -oE '[0-9.]+' | head -1)
        _svc_row "PostgreSQL" "${CGREEN}running${CDEF}" "v${_ver}" "$(_svc_uptime "postgres")"
    else
        _svc_row "PostgreSQL" "${CRED}stopped${CDEF}"
    fi
fi

if [[ "${DKZ_MYSQL_VERSION_INSTALL:-0}" != "0" ]]; then
    if _proc_running "mysqld"; then
        _ver=$(mysqld --version 2>/dev/null | grep -oE '[0-9.]+' | head -1)
        _svc_row "MySQL" "${CGREEN}running${CDEF}" "v${_ver}" "$(_svc_uptime "mysqld")"
    else
        _svc_row "MySQL" "${CRED}stopped${CDEF}"
    fi
fi

separator

# =============================================================================
# Cheatsheet
# =============================================================================

echo -e "  ${CYELLOW}Global:${CDEF}"
echo -e "    motd...........: refresh this message"
if [[ "$DKZ_ENV" == "DEV" ]]; then
    echo -e "    dockraft.......: update dockraft files from upstream git + sync container scripts"
fi
echo -e "    dkzenv.........: list all DKZ_* environment variables"
echo -e "    ss.............: list all linux services"
echo -e "    ll.............: ls -alh (grouped, colored)"
echo -e "    llt............: ls sorted by time (newest last)"
echo -e ""

if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" != "0" ]]; then
    if [[ "${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" != "0" ]]; then
        echo -e "  ${CYELLOW}PHP / Symfony (${DKZ_ENV}):${CDEF}"
    else
        echo -e "  ${CYELLOW}PHP (${DKZ_ENV}):${CDEF}"
    fi
    echo -e "    ci.............: composer install"
    if [[ "$DKZ_ENV" == "DEV" ]]; then
        echo -e "    cu.............: composer update"
        echo -e "    cuf............: composer update --ignore-platform-reqs"
    fi
    if [[ "${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" != "0" ]]; then
        _DDC=""
        _DDCE=""
        if ! doctrine_migrations_installed; then
            _DDC="${CGREY}"
            _DDCE="${CDEF}"
        fi
        if [[ "$DKZ_ENV" == "DEV" ]]; then
            echo -e "    cc.............: symfony cache clear + warmup"
        fi
        echo -e "    -----------------------------------------------------"
        echo -e "    dbv............: doctrine:schema:validate"
        echo -e "    ${_DDC}dbs............: doctrine:migrations:status${_DDCE}"
        echo -e "    ${_DDC}dbl............: doctrine:migrations:list${_DDCE}"
        if [[ "$DKZ_ENV" == "DEV" ]]; then
            echo -e "    ${_DDC}dbd............: doctrine:migrations:diff${_DDCE}"
        fi
        echo -e "    ${_DDC}dbm............: doctrine:migrations:migrate${_DDCE}"
        echo -e "    -----------------------------------------------------"
        echo -e "    symabout.......: bin/console about"
        echo -e "    symdeps........: debug:container --deprecations"
        echo -e "    symenvs........: debug:container --env-vars"
        echo -e "    symroutes......: debug:router (all routes)"
        echo -e "    symroute ?.....: debug:router <route-name>"
        echo -e "    symdotenv......: debug:dotenv"
        echo -e "    symparameters..: debug:container --parameters"
        echo -e "    -----------------------------------------------------"
        if [[ "$DKZ_ENV" == "DEV" ]]; then
            echo -e "    tests..........: run PHPUnit tests"
        else
            echo -e "    deploy....: deploy script (git pull + composer + migrations)"
        fi
    fi
fi

if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
    echo -e "  ${CYELLOW}Angular / NodeJS (${DKZ_ENV}):${CDEF}"
    if [[ "$DKZ_ENV" == "DEV" ]]; then
        echo -e "    ng serve --port ${DKZ_NODEJS_ANGULAR_PORT} --host 0.0.0.0"
        echo -e "    npm run build"
    else
        echo -e "    deploy....: deploy script (git pull + npm build + restart)"
        echo -e "    supervisorctl restart angular   (restart Node.js server)"
    fi
fi

separator

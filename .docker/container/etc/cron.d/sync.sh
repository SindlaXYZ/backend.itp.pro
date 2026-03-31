#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# sync.sh — Periodic sync and maintenance. Lives in cron.d/ alongside cron job files.
# DKZ_* variables are read from /etc/environment (not available in cron by default).
# -----------------------------------------------------------------------------

source /etc/environment 2>/dev/null || true
source /srv/${DKZ_DOMAIN}/.docker/container/scripts/lib.sh

# Prevent lib.sh from rotating the log on every cron invocation — append-only for today.
mkdir -p "$_LIB_LOG_DIR"
_LIB_LOG_INITIALIZED=true

# =============================================================================
# supervisord — reload program configs from volume mount (picks up additions/changes)
# =============================================================================

supervisorctl update >/dev/null 2>&1

# =============================================================================
# DEV-specific tasks
# =============================================================================

if [[ "$DKZ_ENV" == "DEV" ]]; then
    # Sync project cron.tab into /etc/cron.d/crontab — picks up edits without container restart
    install_crontab

    # PHP/Symfony: ensure www-data owns var/ and tmp/ (required by PHP-FPM)
    if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" != "0" ]]; then
        [[ -d "/srv/${DKZ_DOMAIN}/var" ]] && chown -R www-data:www-data "/srv/${DKZ_DOMAIN}/var"
        [[ -d "/tmp/${DKZ_DOMAIN}" ]]     && chown -R www-data:www-data "/tmp/${DKZ_DOMAIN}"
    fi
fi

# =============================================================================
# PROD-specific tasks
# =============================================================================

if [[ "$DKZ_ENV" == "PROD" ]]; then
    if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" != "0" ]]; then
        mkdir -p "/srv/${DKZ_DOMAIN}/var/cache/prod" "/srv/${DKZ_DOMAIN}/var/log/prod" "/srv/${DKZ_DOMAIN}/var/tmp"
        chown -R www-data:www-data "/srv/${DKZ_DOMAIN}/var"
    fi
fi

# =============================================================================
# Every 5 minutes: update DKZ_SRVSPACE and DKZ_TMPSPACE in /etc/environment
# =============================================================================

if [[ $(( $(date +"%M") % 5 )) -eq 0 ]]; then
    log "Updating disk usage stats ..."

    DKZ_SRVSPACE=$(du -sh /srv 2>/dev/null | cut -f1)
    if grep -q "^DKZ_SRVSPACE=" /etc/environment 2>/dev/null; then
        sed -i "s|^DKZ_SRVSPACE=.*|DKZ_SRVSPACE=\"${DKZ_SRVSPACE}\"|" /etc/environment
    else
        echo "DKZ_SRVSPACE=\"${DKZ_SRVSPACE}\"" >> /etc/environment
    fi

    DKZ_TMPSPACE=$(du -sh /tmp 2>/dev/null | cut -f1)
    if grep -q "^DKZ_TMPSPACE=" /etc/environment 2>/dev/null; then
        sed -i "s|^DKZ_TMPSPACE=.*|DKZ_TMPSPACE=\"${DKZ_TMPSPACE}\"|" /etc/environment
    else
        echo "DKZ_TMPSPACE=\"${DKZ_TMPSPACE}\"" >> /etc/environment
    fi

    log "DKZ_SRVSPACE=${DKZ_SRVSPACE} DKZ_TMPSPACE=${DKZ_TMPSPACE}"
fi

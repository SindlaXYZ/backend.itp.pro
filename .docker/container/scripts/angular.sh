#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# angular.sh — Managed by supervisord [program:angular].
#
# Waits for boot.sh to complete npm install (DEV) or npm run build (PROD) by
# polling for the presence of the expected artifact, then starts the server:
#   DEV: ng serve --port ${DKZ_NODEJS_ANGULAR_PORT} --host 0.0.0.0
#   PROD: node dist/${DKZ_DOMAIN}/server/server.mjs
#
# Exits immediately (code 0) if DKZ_NODEJS_ANGULAR_VERSION_INSTALL = 0 (harmless for PHP)
# projects where this program file is still loaded by supervisord.
# -----------------------------------------------------------------------------

# Load environment variables (not available in supervisord-spawned processes)
[[ -f /etc/environment ]] && source /etc/environment

# Load lib.sh for log()
[[ -f /srv/${DKZ_DOMAIN}/.docker/container/scripts/lib.sh ]] && source /srv/${DKZ_DOMAIN}/.docker/container/scripts/lib.sh

# Load nvm so node/ng are available (supervisord does not source /etc/profile.d/)
export NVM_DIR="/root/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

# Only relevant for Angular/NodeJS projects
if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" == "0" ]]; then
    exit 0
fi

_project_dir="/srv/${DKZ_DOMAIN}"

_start_process() {
    local _pid="$1"
    local _label="$2"
    # Give the process a few seconds to start or fail early
    sleep 3
    if kill -0 "$_pid" 2>/dev/null; then
        log "${_label} is running (PID ${_pid})"
    else
        log "ERROR: ${_label} exited unexpectedly — check docker logs for output"
        exit 1
    fi
    # Forward SIGTERM/SIGINT to the child process so supervisord can stop it cleanly
    trap 'kill "$_pid" 2>/dev/null; wait "$_pid"' TERM INT
    wait "$_pid"
}

if [[ "$DKZ_ENV" == "DEV" ]]; then
    # Wait for npm install to create node_modules/.bin/ng
    log "Waiting for npm install to complete (node_modules/.bin/ng) ..."
    while [[ ! -f "${_project_dir}/node_modules/.bin/ng" ]]; do
        sleep 2
    done
    log "npm install complete. Starting ng serve on port ${DKZ_NODEJS_ANGULAR_PORT} ..."
    cd "$_project_dir" || { log "ERROR: cannot cd to ${_project_dir}"; exit 1; }
    ./node_modules/.bin/ng serve --port "${DKZ_NODEJS_ANGULAR_PORT}" --host 0.0.0.0 &
    _start_process $! "ng serve"
else
    # Wait for npm run build to create the SSR server entry point
    _ssr_entry="${_project_dir}/dist/${DKZ_DOMAIN}/server/server.mjs"
    log "Waiting for npm run build to complete (${_ssr_entry}) ..."
    while [[ ! -f "$_ssr_entry" ]]; do
        sleep 5
    done
    log "Build complete. Starting Angular SSR server ..."
    cd "$_project_dir" || { log "ERROR: cannot cd to ${_project_dir}"; exit 1; }
    node "dist/${DKZ_DOMAIN}/server/server.mjs" &
    _start_process $! "node server.mjs"
fi

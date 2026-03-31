#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Dockerfile.sh — Dockraft entry point
#
# If .docker/.env.local does not exist → collect config interactively, write .docker/.env.local, then build
# If .docker/.env.local exists         → source it and build/start Docker
# -----------------------------------------------------------------------------

DKZ_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DKZ_DIR/container/scripts/colors.sh"

IS_MINGW=false
[[ "$(expr substr $(uname -s) 1 5)" == "MINGW" ]] && IS_MINGW=true

# Optional positional parameter: ./Dockerfile.sh [GITHUB_PERSONAL_TOKEN]
# Example: bash .docker/Dockerfile.sh my_github_pat
[[ $# -gt 0 ]] && GITHUB_PERSONAL_TOKEN="$1"

# =============================================================================
# SETUP WIZARD — Handler functions (interactive .env.local config)
# Sourced from scripts/setup/setup-env-local.sh for testability.
# =============================================================================

source "$DKZ_DIR/host/scripts/setup-env-local.sh"

# =============================================================================
# DOCKER LIFECYCLE — Build, run, and manage the container
# =============================================================================

# _check_docker_running — Abort with a clear message if Docker daemon is down

_check_docker_running() {
    if ! docker info >/dev/null 2>&1; then
        echo -e "${CRED}Docker is not running. Please start Docker and try again.${CDEF}"
        exit 1
    fi
}

# _container_exists — Returns 0 if a container with image $DKZ_NAME exists

_container_exists() {
    [ -n "$(docker ps -aqf "ancestor=${DKZ_NAME}")" ]
}

# _container_running — Returns 0 if the container is currently running

_container_running() {
    [ -n "$(docker ps -qf "ancestor=${DKZ_NAME}")" ]
}

# _build_image — Build the Docker image from $DKZ_DIR/Dockerfile
# All DKZ_* variables are passed as --build-arg.
# Uses a subshell + cd to avoid passing paths with special characters (e.g. ~)
# directly to Docker, which causes BuildKit path resolution failures on MINGW.

_build_image() {
    echo -e "\n${CYELLOW}Building image: ${DKZ_NAME} ...${CDEF}"

    _install_host_nginx

    export DOCKER_BUILDKIT=1

    # Pass GitHub token as a BuildKit secret if .github-token exists.
    # The secret is available only during the RUN --mount=type=secret step
    # and never appears in image layers or docker history.
    local _secret_flag=""
    if [[ -f "${DKZ_DIR}/.github-token" && -s "${DKZ_DIR}/.github-token" ]]; then
        _secret_flag="--secret id=DKZ_GITHUB_TOKEN,src=.github-token"
    fi

    # cd into DKZ_DIR so Docker receives "." as the build context — avoids
    # MINGW path conversion issues with special characters in the path.
    (
        cd "${DKZ_DIR}" || { echo -e "${CRED}Cannot cd to ${DKZ_DIR}${CDEF}"; exit 1; }
        # shellcheck disable=SC2086
        docker build \
            --no-cache \
            $_secret_flag \
            --build-arg DKZ_ENV="${DKZ_ENV}" \
            --build-arg DKZ_DIST="${DKZ_DIST}" \
            --build-arg DKZ_DOMAIN="${DKZ_DOMAIN}" \
            --build-arg DKZ_DOMAINS="${DKZ_DOMAINS}" \
            --build-arg DKZ_GIT_REPO_URI="${DKZ_GIT_REPO_URI}" \
            --build-arg DKZ_GIT_BRANCH_PRODUCTION="${DKZ_GIT_BRANCH_PRODUCTION}" \
            --build-arg DKZ_NODEJS_INSTALL="${DKZ_NODEJS_INSTALL:-0}" \
            --build-arg DKZ_NODEJS_ANGULAR_VERSION_INSTALL="${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" \
            --build-arg DKZ_NODEJS_ANGULAR_PORT="${DKZ_NODEJS_ANGULAR_PORT:-4000}" \
            --build-arg DKZ_PORT80="${DKZ_PORT80}" \
            --build-arg DKZ_PHP_VERSION_INSTALL="${DKZ_PHP_VERSION_INSTALL:-0}" \
            --build-arg DKZ_PHP_SYMFONY_VERSION_INSTALL="${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" \
            --build-arg DKZ_PHP_SYMFONY_AURORA_INSTALL="${DKZ_PHP_SYMFONY_AURORA_INSTALL:-0}" \
            --build-arg DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL="${DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL:-0}" \
            --build-arg DKZ_PHP_XDEBUG="${DKZ_PHP_XDEBUG:-0}" \
            --build-arg DKZ_POSTGRESQL_VERSION_INSTALL="${DKZ_POSTGRESQL_VERSION_INSTALL:-0}" \
            --build-arg DKZ_POSTGRESQL_USERNAME="${DKZ_POSTGRESQL_USERNAME}" \
            --build-arg DKZ_POSTGRESQL_DATABASE="${DKZ_POSTGRESQL_DATABASE}" \
            --build-arg DKZ_MYSQL_VERSION_INSTALL="${DKZ_MYSQL_VERSION_INSTALL:-0}" \
            --build-arg DKZ_AI_CODEX_INSTALL="${DKZ_AI_CODEX_INSTALL:-0}" \
            --build-arg DKZ_AI_GEMINI_INSTALL="${DKZ_AI_GEMINI_INSTALL:-0}" \
            --build-arg DKZ_AI_CLAUDE_CODE_INSTALL="${DKZ_AI_CLAUDE_CODE_INSTALL:-0}" \
            -t "${DKZ_NAME}" \
            .
    )
}

# _check_ports_available — Abort with a clear message if required host ports are already bound.
# curl exit code 7 = "Failed to connect to host" = port is FREE (nothing listening).
# Any other exit code (0 = got a response, 52 = empty reply, etc.) means the port is occupied.

_check_ports_available() {
    local _occupied=0

    curl -sm5 "127.0.0.1:${DKZ_PORT80}" >/dev/null 2>&1
    if [[ $? -ne 7 ]]; then
        echo -e "${CRED}✖ Port ${DKZ_PORT80} (HTTP) is already in use${CDEF}"
        _occupied=1
    else
        echo -e "${CGREEN}✔ Port ${DKZ_PORT80} (HTTP) is free${CDEF}"
    fi

    if [[ "$DKZ_ENV" == "PROD" ]]; then
        curl -sm5 "127.0.0.1:${DKZ_PORT443}" >/dev/null 2>&1
        if [[ $? -ne 7 ]]; then
            echo -e "${CRED}✖ Port ${DKZ_PORT443} (HTTPS) is already in use${CDEF}"
            _occupied=1
        else
            echo -e "${CGREEN}✔ Port ${DKZ_PORT443} (HTTPS) is free${CDEF}"
        fi
    fi

    if [[ $_occupied -ne 0 ]]; then
        read -n1 -rsp $'Press any key to exit.\n'
        exit 1
    fi
}

# _run_container — Start a new container from the built image
# DEV: mounts the project root as a volume; auto-exposes service ports
# PROD: no volume; also exposes port 443
# Extra ports from DKZ_SHARED_PORTS (HOST:CONTAINER,...)

_run_container() {
    echo -e "\n${CYELLOW}Starting container: ${DKZ_NAME} on port ${DKZ_PORT80} ...${CDEF}"

    _check_ports_available

    local shared_ports="-p ${DKZ_PORT80}:80"

    # Append extra port mappings from DKZ_SHARED_PORTS (HOST:CONTAINER,...)
    if [[ -n "$DKZ_SHARED_PORTS" ]]; then
        IFS=',' read -ra _extra_ports <<< "$DKZ_SHARED_PORTS"
        for _entry in "${_extra_ports[@]}"; do
            IFS=':' read -ra _pair <<< "$_entry"
            if [[ "${_pair[0]}" =~ ^[0-9]+$ ]] && [[ "${_pair[1]}" =~ ^[0-9]+$ ]]; then
                shared_ports+=" -p ${_pair[0]}:${_pair[1]}"
            fi
        done
    fi

    # Resolve the project root (parent of .docker/)
    local project_root
    project_root=$(dirname "${DKZ_DIR}")

    if [[ "$IS_MINGW" == true ]]; then
        # Convert POSIX MINGW path (/w/project) → Windows path (W:/project) for Docker volume
        local _drive="${project_root:1:1}"
        local _rest="${project_root:3}"
        project_root="${_drive^^}:/${_rest}"
    fi

    # Build runtime_env dynamically from .env.local — all DKZ_* variables are passed
    # to the container via -e, except host-side-only variables that are only used to
    # construct the docker run command itself and have no meaning inside the container.
    local _host_only="DKZ_RUN_RESTART|DKZ_SHARED_MEMORY|DKZ_NAME|DKZ_PORT_PREFIX|DKZ_SHARED_PORTS|DKZ_GIT_BRANCH_DEVELOPMENT|DKZ_GIT_BRANCH_STAGING"
    local runtime_env=()
    while IFS='=' read -r _key _; do
        [[ "$_key" =~ ^($_host_only)$ ]] && continue
        runtime_env+=(-e "${_key}=${!_key}")
    done < <(grep -E '^DKZ_[A-Z_0-9]+=' "${DKZ_DIR}/.env.local")

    if [[ "$DKZ_ENV" == "DEV" ]]; then
        # Auto-expose service ports based on installed services
        [[ "${DKZ_MYSQL_VERSION_INSTALL:-0}" != "0" ]] && shared_ports+=" -p ${DKZ_PORT3306}:3306"
        [[ "${DKZ_POSTGRESQL_VERSION_INSTALL:-0}" != "0" ]] && shared_ports+=" -p ${DKZ_PORT5432}:5432"
        [[ "${DKZ_RABBITMQ_INSTALL:-0}"   == "1" ]] && shared_ports+=" -p ${DKZ_PORT5672}:5672 -p ${DKZ_PORT15672}:15672"
        [[ "${DKZ_MONGODB_INSTALL:-0}"    == "1" ]] && shared_ports+=" -p ${DKZ_PORT27017}:27017"

        # cached     - the host’s view is authoritative (permit delays before updates on the host appear in the container) | use when the host performs changes, the container is in read only mode
        # delegated  - the container’s view is authoritative (permit delays before updates on the container appear in the host) | use when docker container performs changes, host is in read only mode
        # vendor:/srv/$DKZ_DOMAIN/vendor/ - will NOT share /vendor between host & container (increased performance, but IDE will be buggy)
        # -v vendor:/... - vendor will be shared to all containers, if use the same volume name

        # DO NOT DOUBLE-QUOTE $shared_ports
        # shellcheck disable=SC2086
        set -x
        docker run $shared_ports \
            --name "${DKZ_NAME}" \
            --shm-size="${DKZ_SHARED_MEMORY}" \
            --restart "${DKZ_RUN_RESTART}" \
            "${runtime_env[@]}" \
            -v "${project_root}:/srv/${DKZ_DOMAIN}:delegated" \
            -v "${DKZ_NAME}:/srv/${DKZ_DOMAIN}/vendor/" \
            -dit "${DKZ_NAME}"
        set +x
    else
        # PROD: no volume mount; expose HTTPS port as well
        # DO NOT DOUBLE-QUOTE $shared_ports
        # shellcheck disable=SC2086
        set -x
        docker run -i -d $shared_ports \
            -p "${DKZ_PORT443}:443" \
            --name "${DKZ_NAME}" \
            --shm-size="${DKZ_SHARED_MEMORY}" \
            --restart "${DKZ_RUN_RESTART}" \
            "${runtime_env[@]}" \
            "${DKZ_NAME}"
        set +x
    fi
}

# _connect_to_container — Open an interactive bash shell inside the container
# Uses winpty on MINGW (required for TTY allocation under Windows)

_connect_to_container() {
    local container_id
    container_id=$(docker ps -qf "ancestor=${DKZ_NAME}")

    if [[ -z "$container_id" ]]; then
        echo -e "${CRED}Container is not running.${CDEF}"
        return 1
    fi

    if [[ "$IS_MINGW" == true ]]; then
        winpty docker exec -it "${container_id}" bash
    else
        docker exec -it "${container_id}" bash
    fi
}

# _restart_container — Stop (if running) then start the container

_restart_container() {
    local container_id
    container_id=$(docker ps -aqf "ancestor=${DKZ_NAME}")

    if [[ -z "$container_id" ]]; then
        echo -e "${CRED}No container found for image ${DKZ_NAME}.${CDEF}"
        return 1
    fi

    if _container_running; then
        echo -e "${CYELLOW}Stopping container ...${CDEF}"
        docker stop "${container_id}"
    fi

    echo -e "${CYELLOW}Starting container ...${CDEF}"
    docker start "${container_id}"
}

# _rebuild_container — Stop, remove container + image, then rebuild from scratch

_rebuild_container() {
    echo -e "\n${CYELLOW}Rebuilding image and container ...${CDEF}"

    local container_id
    container_id=$(docker ps -aqf "ancestor=${DKZ_NAME}")

    if [[ -n "$container_id" ]]; then
        if _container_running; then
            docker stop "${container_id}"
        fi
        docker rm "${container_id}"
    fi

    docker rmi -f "${DKZ_NAME}" 2>/dev/null || true
    _build_image && _run_container
}

# _next_action — Interactive menu shown after the container is ready

_next_action() {
    if _container_running; then
        echo -e "\n${CGREEN}Container ${DKZ_NAME} is running on port ${DKZ_PORT80}.${CDEF}"
    else
        echo -e "\n${CYELLOW}Container ${DKZ_NAME} exists but is stopped.${CDEF}"
    fi

    echo ""
    read -r -e -p "$(echo -e "${CYELLOW}[1]${CDEF} Exit\n${CYELLOW}[2]${CDEF} Rebuild image\n${CYELLOW}[3]${CDEF} Connect to container (bash)\n${CYELLOW}[4]${CDEF} Restart container\n> ")" _action

    # Empty input (Enter) → default to option 3
    [[ -z "$_action" ]] && _action="3"

    case "$_action" in
        1)
            exit 0
            ;;
        2)
            _rebuild_container
            _next_action
            ;;
        3)
            if ! _container_running; then
                _restart_container
            fi
            _connect_to_container
            _next_action
            ;;
        4)
            _restart_container
            _next_action
            ;;
        *)
            _next_action
            ;;
    esac
}

# _install_host_nginx — Install nginx host proxy configs for PROD Linux deployments.
# Reads templates from .docker/host/etc/nginx/conf.d/*.conf.dist, replaces __DOMAIN__
# and __PORT80__ placeholders, and copies the resulting .conf files to /etc/nginx/conf.d/
# on the host. Prompts before overwriting existing files. Reloads nginx after installation.
# No-op on MINGW or when DKZ_ENV=DEV.

_install_host_nginx() {
    [[ "$IS_MINGW" == true || "$DKZ_ENV" == "DEV" ]] && return

    local host_nginx_dir="${DKZ_DIR}/host/etc/nginx/conf.d"

    if [[ ! -d "$host_nginx_dir" ]]; then
        echo -e "${CYELLOW}Host nginx template directory not found: ${host_nginx_dir} — skipping${CDEF}"
        return
    fi

    if [[ ! -d /etc/nginx/conf.d ]]; then
        echo -e "${CRED}Host nginx directory /etc/nginx/conf.d does not exist.${CDEF}"
        read -n1 -rsp $'Press any key to continue / CTRL+C to exit.\n'
        return
    fi

    echo -e "\n${CYELLOW}Installing host nginx proxy configs ...${CDEF}"

    # Build domain list: main domain + any extras from DKZ_DOMAINS
    local -a _domains=("$DKZ_DOMAIN")
    if [[ -n "$DKZ_DOMAINS" ]]; then
        IFS=',' read -ra _extra <<< "$DKZ_DOMAINS"
        for _d in "${_extra[@]}"; do
            _d="${_d// /}"
            [[ -n "$_d" && "$_d" != "$DKZ_DOMAIN" ]] && _domains+=("$_d")
        done
    fi

    local _tmpl="${host_nginx_dir}/__DOMAIN__.conf.dist"

    _install_nginx_conf() {
        local _src="$1" _dest="$2"
        if [[ -f "$_dest" ]]; then
            read -r -p "$(echo -e "${CYELLOW}${_dest} already exists:\n  [1] overwrite\n  [2] skip\n${CDEF}")" _choice
            [[ "$_choice" != "1" ]] && { echo -e "  skipped ${_dest}"; return; }
        fi
        cp -f "$_src" "$_dest"
        echo -e "${CGREEN}  installed ${_dest}${CDEF}"
    }

    for _domain in "${_domains[@]}"; do
        local _tmp
        _tmp=$(mktemp /tmp/dkz-nginx-XXXXXX.conf)
        cp -f "$_tmpl" "$_tmp"
        sed -i -e "s/__DOMAIN__/${_domain}/g" -e "s/__PORT80__/${DKZ_PORT80}/g" "$_tmp"
        _install_nginx_conf "$_tmp" "/etc/nginx/conf.d/${_domain}.conf"
        rm -f "$_tmp"
    done

    # Adminer proxy config — PHP/Symfony projects only, main domain only
    if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" != "0" ]]; then
        local _adminer_tmpl="${host_nginx_dir}/adminer.__DOMAIN__.conf.dist"
        if [[ -f "$_adminer_tmpl" ]]; then
            local _tmp_adminer
            _tmp_adminer=$(mktemp /tmp/dkz-nginx-XXXXXX.conf)
            cp -f "$_adminer_tmpl" "$_tmp_adminer"
            sed -i -e "s/__DOMAIN__/${DKZ_DOMAIN}/g" -e "s/__PORT80__/${DKZ_PORT80}/g" "$_tmp_adminer"
            _install_nginx_conf "$_tmp_adminer" "/etc/nginx/conf.d/adminer.${DKZ_DOMAIN}.conf"
            rm -f "$_tmp_adminer"
        fi
    fi

    echo -e "${CYELLOW}Reloading nginx ...${CDEF}"
    service nginx reload
    echo -e "${CGREEN}Host nginx proxy configs installed.${CDEF}"
}

# =============================================================================
# docker_build_or_rebuild_or_connect_or_restart_the_container — Main entry point: checks Docker, builds image, starts container
# docker_build_or_rebuild_or_connect_or_restart_the_container is the first called function when the ./Dockerfile.sh is executed
# - if the docker cthe ontainer/image does not exist, will automatically start to create the image and run the container
# - if the docker container exists, then the user will be asked what is the next action (if the user simple press ENTER then action [3] Connect to container will be executed):
# -- [1] Exit
# -- [2] Rebuild image
# -- [3] Connect to container (bash)
# -- [4] Restart container
# =============================================================================
docker_build_or_rebuild_or_connect_or_restart_the_container() {
    _check_docker_running

    if ! _container_exists; then
        echo -e "\n${CYELLOW}No existing container found. Building image and starting container ...${CDEF}"

        if ! _build_image; then
            echo -e "${CRED}Image build failed. Aborting.${CDEF}"
            exit 1
        fi
        if ! _run_container; then
            echo -e "${CRED}Container failed to start. Aborting.${CDEF}"
            exit 1
        fi
    fi

    _next_action
}

# =============================================================================
# _load_env — Source .env.local
# =============================================================================

_load_env() {
    source "$DKZ_DIR/.env.local"
    [[ "$DKZ_ENV" == "PROD" ]] && DKZ_PHP_XDEBUG=0
}

# =============================================================================
# _setup — Run interactive setup wizard, then load the generated .env.local
# =============================================================================

_setup() {
    setup_env_local
}

# =============================================================================
# _init_project_git — Initialize .git for the project after first-time dockraft bootstrap.
#
# The README bootstrap clones dockraft into .dockraft/, copies .docker/ out, then
# deletes .dockraft/ — so there is no .git in the project root when Dockerfile.sh runs.
# This function initializes a fresh git repo using DKZ_GIT_REPO_URI and
# DKZ_GIT_BRANCH_DEVELOPMENT collected by setup_env_local().
# If .git already exists (user running on an existing repo), this is a no-op.
# =============================================================================

_init_project_git() {
    local project_root
    project_root="$(dirname "${DKZ_DIR}")"

    # Already has a git repo — leave it alone
    [[ -d "${project_root}/.git" ]] && return

    local branch="${DKZ_GIT_BRANCH_DEVELOPMENT:-main}"

    # On MINGW, apply the +Sindla SSH alias for multi-account SSH key routing.
    # DKZ_GIT_REPO_URI is always stored as the canonical URI (without +Sindla).
    local remote_uri="$DKZ_GIT_REPO_URI"
    if [[ "$IS_MINGW" == true && "${remote_uri:0:15}" == "git@github.com:" ]]; then
        remote_uri="${remote_uri/git@github.com:/git@github.com+Sindla:}"
    fi

    echo -e "\n${CYELLOW}Initializing git repository for project ...${CDEF}"

    git -C "$project_root" init
    git -C "$project_root" symbolic-ref HEAD "refs/heads/${branch}"
    git -C "$project_root" remote add origin "$remote_uri"
    git -C "$project_root" config user.email "liviu2019+SindlaXYZ+github.com@sindla.com"
    git -C "$project_root" config user.name "SindlaXYZ"

    echo -e "${CGREEN}Git initialized: branch '${branch}', remote origin → ${remote_uri}${CDEF}"
}

# =============================================================================
# _ensure_github_token — Create .docker/.github-token if not present.
#
# The token is passed to docker build as a BuildKit secret (--secret) so it
# is never stored in image layers or visible in docker history.
# The file itself must be gitignored (.docker/.github-token).
# =============================================================================

_ensure_github_token() {
    local token_file="$DKZ_DIR/.github-token"

    # Already written from a previous run — nothing to do
    [[ -f "$token_file" ]] && return

    # GITHUB_PERSONAL_TOKEN passed as the first positional parameter: bash .docker/Dockerfile.sh <token>
    if [[ -n "$GITHUB_PERSONAL_TOKEN" ]]; then
        echo -n "$GITHUB_PERSONAL_TOKEN" > "$token_file"
        chmod 600 "$token_file"
        return
    fi

    # GH_PAT is exported by the README bootstrap command before calling this script:
    #   read -s -p "GitHub Personal Access Token: " GH_PAT && export GH_PAT && bash .docker/Dockerfile.sh
    # Reuse it directly so the user is not asked twice.
    if [[ -n "$GH_PAT" ]]; then
        echo -n "$GH_PAT" > "$token_file"
        chmod 600 "$token_file"
        return
    fi

    # GH_PAT not available (e.g. Dockerfile.sh called directly without the README bootstrap).
    # Ask the user once; leave empty to skip (public repositories work without a token).
    echo -e "\n${CYELLOW}GitHub Personal Access Token${CDEF} — used by 'dockraft' inside the container to update itself."
    echo -e "Leave empty to skip (only required for private repositories)."
    read -r -s -p "Token: " _token
    echo ""

    echo -n "$_token" > "$token_file"
    chmod 600 "$token_file"
}

# =============================================================================
# Entry point
# =============================================================================

if [[ ! -f "$DKZ_DIR/.env.local" ]]; then
    _setup
    _load_env
    [[ "$DKZ_ENV" == "DEV" ]] && _init_project_git
else
    _load_env
fi

_ensure_github_token
docker_build_or_rebuild_or_connect_or_restart_the_container

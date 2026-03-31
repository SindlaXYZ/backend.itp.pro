#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# setup-env-local.sh — Interactive .env.local setup wizard handlers
#
# Sourced by Dockerfile.sh before setup_env_local() is called.
# Each _ask_* function handles one key (or a group of related keys) from .env.
# Functions depend on color variables being defined (source colors.sh first).
# -----------------------------------------------------------------------------

# =============================================================================
# SETUP WIZARD — Handler functions (interactive .env.local config)
# =============================================================================

# _ask_env — Handler for DKZ_ENV
# Prompts for environment choice and appends DKZ_ENV + DKZ_SYMFONY_ENV
# Usage: _ask_env <path-to-.env> <path-to-.env.local>

_ask_env() {
    local env="$1"
    local env_local="$2"

    [[ "$IS_MINGW" == true ]] && local default_choice=1 || local default_choice=4

    echo -e "\n${CYELLOW}Environment:${CDEF}"
    read -r -e -p "$(echo -e "${CYELLOW}[1]${CDEF} Development\n${CYELLOW}[4]${CDEF} Production\nDKZ_ENV: ")" \
      -i "$default_choice" environment

    if [[ "$environment" != "1" && "$environment" != "4" ]]; then
        echo -e "${CRED}Incorrect choice. Try again...${CDEF}"
        _ask_env "$env" "$env_local"
        return
    fi

    [[ "$environment" == "1" ]] && DKZ_ENV="DEV" || DKZ_ENV="PROD"

    echo "DKZ_ENV=$DKZ_ENV" >> "$env_local"
    sed -i "s|^DKZ_ENV=.*|DKZ_ENV=$DKZ_ENV|" "$env"
}

# _ask_angular21 — Handler for DKZ_NODEJS_ANGULAR_VERSION_INSTALL
# Prompts for the Angular version to install (0 = skip, e.g. 21 = Angular 21).
# When set to a non-zero version, PHP/PostgreSQL/MySQL/Memcached/MongoDB/RabbitMQ are silently skipped
# by their respective handlers (they read DKZ_NODEJS_ANGULAR_VERSION_INSTALL from the re-sourced .env.local).
# Usage: _ask_angular21 <path-to-.env> <path-to-.env.local> <prefill>

_ask_angular21() {
    local env="$1"
    local env_local="$2"
    local prefill="${3:-0}"

    # Angular requires NodeJS — skip silently if DKZ_NODEJS_INSTALL=0
    if [[ "${DKZ_NODEJS_INSTALL:-0}" == "0" ]]; then
        echo "DKZ_NODEJS_ANGULAR_VERSION_INSTALL=0" >> "$env_local"
        sed -i "s|^DKZ_NODEJS_ANGULAR_VERSION_INSTALL=.*|DKZ_NODEJS_ANGULAR_VERSION_INSTALL=0|" "$env"
        return
    fi

    echo -e "\n${CYELLOW}Angular version to install (0 = skip, e.g. 21 = Angular 21):${CDEF}"
    read -r -e -p "DKZ_NODEJS_ANGULAR_VERSION_INSTALL: " \
      -i "$prefill" angular21_input

    if ! [[ "$angular21_input" =~ ^[0-9]+$ ]]; then
        echo -e "${CRED}Must be 0 or a positive integer (e.g. 21). Try again...${CDEF}"
        _ask_angular21 "$env" "$env_local" "$prefill"
        return
    fi

    echo "DKZ_NODEJS_ANGULAR_VERSION_INSTALL=$angular21_input" >> "$env_local"
    sed -i "s|^DKZ_NODEJS_ANGULAR_VERSION_INSTALL=.*|DKZ_NODEJS_ANGULAR_VERSION_INSTALL=$angular21_input|" "$env"
}

# _ask_run_restart — Handler for DKZ_RUN_RESTART
# Prompts for Docker restart policy and appends DKZ_RUN_RESTART
# Usage: _ask_run_restart <path-to-.env> <path-to-.env.local>

_ask_run_restart() {
    local env="$1"
    local env_local="$2"

    [[ "$DKZ_ENV" == "PROD" ]] && local default_choice=2 || local default_choice=1

    echo -e "\n${CYELLOW}Docker --restart policy:${CDEF}"
    read -r -e -p "$(echo -e "${CYELLOW}[1]${CDEF} no\n${CYELLOW}[2]${CDEF} unless-stopped\n${CYELLOW}[3]${CDEF} always\nDKZ_RUN_RESTART: ")" \
        -i "$default_choice" restart_choice

    local restart_value
    case "$restart_choice" in
        2) restart_value=unless-stopped ;;
        3) restart_value=always ;;
        *) restart_value=no ;;
    esac

    echo "DKZ_RUN_RESTART=$restart_value" >> "$env_local"
    sed -i "s|^DKZ_RUN_RESTART=.*|DKZ_RUN_RESTART=$restart_value|" "$env"
}

# _ask_dist — Handler for DKZ_DIST
# Prompts for Docker base image and appends DKZ_DIST
# Usage: _ask_dist <path-to-.env> <path-to-.env.local> <default-value>

_ask_dist() {
    local env="$1"
    local env_local="$2"
    local default_dist="$3"

    echo -e "\n${CYELLOW}Docker base image:${CDEF}"
    read -r -e -p "DKZ_DIST: " -i "$default_dist" dist_value

    if [[ -z "$dist_value" ]]; then
        echo -e "${CRED}Value cannot be empty. Try again...${CDEF}"
        _ask_dist "$env" "$env_local" "$default_dist"
        return
    fi

    echo "DKZ_DIST=$dist_value" >> "$env_local"
    sed -i "s|^DKZ_DIST=.*|DKZ_DIST=$dist_value|" "$env"
}

# _ask_shared_memory — Handler for DKZ_SHARED_MEMORY
# Prompts for Docker --shm-size and appends DKZ_SHARED_MEMORY
# Usage: _ask_shared_memory <path-to-.env> <path-to-.env.local> <default-value>

_ask_shared_memory() {
    local env="$1"
    local env_local="$2"
    local default_shm="$3"

    echo -e "\n${CYELLOW}Docker shared memory size (--shm-size):${CDEF}"
    read -r -e -p "DKZ_SHARED_MEMORY: " -i "$default_shm" shm_value

    if [[ -z "$shm_value" ]]; then
        echo -e "${CRED}Value cannot be empty. Try again...${CDEF}"
        _ask_shared_memory "$env" "$env_local" "$default_shm"
        return
    fi

    echo "DKZ_SHARED_MEMORY=$shm_value" >> "$env_local"
    sed -i "s|^DKZ_SHARED_MEMORY=.*|DKZ_SHARED_MEMORY=$shm_value|" "$env"
}

# _ask_domain — Handler for DKZ_DOMAIN
# Prompts for the project domain and appends DKZ_DOMAIN
# Uses $newDomain if already set (eg: called from setup_new_project), otherwise
# guesses from the current working directory. Sets $newDomain in the caller's
# scope for use by downstream keys (DKZ_DOMAINS, DKZ_NAME, etc.)
# Usage: _ask_domain <path-to-.env> <path-to-.env.local>

_ask_domain() {
    local env="$1"
    local env_local="$2"
    local prefill="${3:-}"

    # Priority: $prefill (.env value) > $newDomain > project root directory name
    local default_domain="${prefill:-$newDomain}"
    if [[ -z "$default_domain" ]]; then
        default_domain=$(basename "$(dirname "$DKZ_DIR")")
        [[ "$default_domain" =~ \. ]] || default_domain=""
    fi

    echo -e "\n${CYELLOW}Domain (eg: example.com):${CDEF}"
    read -r -e -p "DKZ_DOMAIN: " -i "$default_domain" domain_value

    if [[ -z "$domain_value" ]]; then
        echo -e "${CRED}Value cannot be empty. Try again...${CDEF}"
        _ask_domain "$env" "$env_local" "$prefill"
        return
    fi

    echo "DKZ_DOMAIN=$domain_value" >> "$env_local"
    sed -i "s|^DKZ_DOMAIN=.*|DKZ_DOMAIN=$domain_value|" "$env"
    newDomain="$domain_value"
}

# _ask_domains — Handler for DKZ_DOMAINS
# Prompts for comma-separated list of domains and appends DKZ_DOMAINS
# Uses $newDomain as default (set by _ask_domain)
# Usage: _ask_domains <path-to-.env> <path-to-.env.local>

_ask_domains() {
    local env="$1"
    local env_local="$2"
    local prefill="${3:-}"

    # Strip comma-separated placeholder lists (eg: __DOMAIN1__,__DOMAIN2__) missed by the loop-level check
    [[ "$prefill" =~ __[A-Z0-9_]+__ ]] && prefill=""

    echo -e "\n${CYELLOW}Additional domains (comma-separated):${CDEF}"
    read -r -e -p "DKZ_DOMAINS: " -i "${prefill:-$newDomain}" domains_value

    [[ -z "$domains_value" ]] && domains_value="$newDomain"

    echo "DKZ_DOMAINS=$domains_value" >> "$env_local"
    sed -i "s|^DKZ_DOMAINS=.*|DKZ_DOMAINS=$domains_value|" "$env"
}

# _ask_name — Handler for DKZ_NAME
# Prompts for Docker container name and appends DKZ_NAME
# Default: $newDomain with non-alphanumeric chars replaced by underscore
#          (eg: example.com → example_com)
# Sets $dockerName in the caller's scope for downstream use
# Usage: _ask_name <path-to-.env> <path-to-.env.local>

_ask_name() {
    local env="$1"
    local env_local="$2"
    local prefill="${3:-}"
    local default_name

    if [[ -n "$prefill" ]]; then
        default_name="$prefill"
    else
        default_name=$(echo "${dockerName:-$newDomain}" | sed 's/[^a-zA-Z0-9]/_/g')
    fi

    echo -e "\n${CYELLOW}Docker container name:${CDEF}"
    read -r -e -p "DKZ_NAME: " -i "$default_name" name_value

    if [[ -z "$name_value" ]]; then
        echo -e "${CRED}Value cannot be empty. Try again...${CDEF}"
        _ask_name "$env" "$env_local" "$prefill"
        return
    fi

    echo "DKZ_NAME=$name_value" >> "$env_local"
    sed -i "s|^DKZ_NAME=.*|DKZ_NAME=$name_value|" "$env"
    dockerName="$name_value"
}

# _ask_port_prefix — Handler for DKZ_PORT_PREFIX
# Prompts for port prefix (2000-2099), validates, appends DKZ_PORT_PREFIX and
# all derived DKZ_PORT* vars to .env.local, and updates .env
# Usage: _ask_port_prefix <path-to-.env> <path-to-.env.local>

_ask_port_prefix() {
    local env="$1"
    local env_local="$2"
    local prefill="${3:-}"
    local default_prefix="${dockerPortPrefix:-$prefill}"

    # Well-known domain → port mappings (only when no explicit default)
    if [[ -z "$default_prefix" ]]; then
        case "$newDomain" in
        example.com) default_prefix=2000 ;;
        sindla.com)  default_prefix=2001 ;;
        sindla.ro)   default_prefix=2002 ;;
        nace.tld)    default_prefix=2003 ;;
        esac
    fi

    echo -e "\n${CYELLOW}Docker port prefix (min: 2000 / max: 2099):${CDEF}"
    read -r -e -p "DKZ_PORT_PREFIX: " -i "$default_prefix" port_value

    if [[ -z "$port_value" ]] || [ "$port_value" -lt 2000 ] || [ "$port_value" -gt 2099 ]; then
        echo -e "${CRED}Port prefix must be between 2000 and 2099. Try again...${CDEF}"
        _ask_port_prefix "$env" "$env_local" "$prefill"
        return
    fi

    echo "DKZ_PORT_PREFIX=$port_value" >> "$env_local"
    sed -i "s|^DKZ_PORT_PREFIX=.*|DKZ_PORT_PREFIX=$port_value|" "$env"

    {
        echo "DKZ_PORT20=${port_value}0"
        echo "DKZ_PORT21=${port_value}1"
        echo "DKZ_PORT22=${port_value}2"
        echo "DKZ_PORT80=${port_value}8"    # HTTP
        echo "DKZ_PORT443=${port_value}4"   # HTTPS
        echo "DKZ_PORT3306=${port_value}3"  # MySQL
        echo "DKZ_PORT5432=${port_value}5"  # PostgreSQL
        echo "DKZ_PORT5672=${port_value}6"  # RabbitMQ connections
        echo "DKZ_PORT15672=${port_value}7" # RabbitMQ management
        echo "DKZ_PORT27017=${port_value}9" # MongoDB
    } >> "$env_local"
}

# _ask_self_modify — Handler for DKZ_SELF_MODIFY
# Prompts for self-modify flag (0/1) and appends DKZ_SELF_MODIFY
# Usage: _ask_self_modify <path-to-.env> <path-to-.env.local> <default>

_ask_self_modify() {
    local env="$1"
    local env_local="$2"
    local default_value="${3:-1}"

    echo -e "\n${CYELLOW}Self-modify (allow Dockraft to update its own files):${CDEF}"
    read -r -e -p "$(echo -e "${CYELLOW}[0]${CDEF} No\n${CYELLOW}[1]${CDEF} Yes\nDKZ_SELF_MODIFY: ")" \
        -i "$default_value" self_modify_value

    if [[ "$self_modify_value" != "0" && "$self_modify_value" != "1" ]]; then
        echo -e "${CRED}Incorrect choice. Try again...${CDEF}"
        _ask_self_modify "$env" "$env_local" "$default_value"
        return
    fi

    echo "DKZ_SELF_MODIFY=$self_modify_value" >> "$env_local"
    sed -i "s|^DKZ_SELF_MODIFY=.*|DKZ_SELF_MODIFY=$self_modify_value|" "$env"
}

# _ask_shared_ports — Handler for DKZ_SHARED_PORTS
# Prompts for extra port mappings (HOST:CONTAINER,...) and appends DKZ_SHARED_PORTS
# Optional — empty is valid (no extra ports beyond the defaults)
# Usage: _ask_shared_ports <path-to-.env> <path-to-.env.local>

_ask_shared_ports() {
    local env="$1"
    local env_local="$2"

    echo -e "\n${CYELLOW}Extra shared ports (HOST:CONTAINER,...) — leave empty to skip:${CDEF}"
    read -r -e -p "DKZ_SHARED_PORTS: " -i "" shared_ports_value

    echo "DKZ_SHARED_PORTS=$shared_ports_value" >> "$env_local"
    sed -i "s|^DKZ_SHARED_PORTS=.*|DKZ_SHARED_PORTS=$shared_ports_value|" "$env"
}

# _ask_git_repo_uri — Handler for DKZ_GIT_REPO_URI
# Default: template from .env with __DOMAIN__ replaced by $newDomain
# DKZ_GIT_REPO_URI is always saved as the canonical URI (without +Sindla).
# _init_project_git() applies the +Sindla SSH alias on MINGW at git remote add time.
# Sets $gitRepository, $DKZ_GIT_REPO_OWNER_VAR, $DKZ_GIT_REPO_NAME_VAR for downstream keys
# Usage: _ask_git_repo_uri <path-to-.env> <path-to-.env.local> <template>

_ask_git_repo_uri() {
    local env="$1"
    local env_local="$2"
    local template="$3"

    local default_uri="${gitRepository:-${template//__DOMAIN__/$newDomain}}"

    echo -e "\n${CYELLOW}GIT repository URI:${CDEF}"
    read -r -e -p "DKZ_GIT_REPO_URI: " -i "$default_uri" git_uri_value

    if [[ -z "$git_uri_value" ]]; then
        echo -e "${CRED}Value cannot be empty. Try again...${CDEF}"
        _ask_git_repo_uri "$env" "$env_local" "$template"
        return
    fi

    echo "DKZ_GIT_REPO_URI=$git_uri_value" >> "$env_local"
    sed -i "s|^DKZ_GIT_REPO_URI=.*|DKZ_GIT_REPO_URI=$git_uri_value|" "$env"

    # Set downstream variables used by DKZ_GIT_REPO_OWNER and DKZ_GIT_REPO_NAME
    gitRepository="$git_uri_value"
    local basename="${git_uri_value##*/}"
    DKZ_GIT_REPO_OWNER_VAR=$(echo "$git_uri_value" | cut -d: -f2 | cut -d"/" -f1)
    DKZ_GIT_REPO_NAME_VAR="${basename%.*}"
}

# _ask_git_branch — Shared handler for DKZ_GIT_*_BRANCH keys
# DKZ_GIT_BRANCH_STAGING and DKZ_GIT_BRANCH_PRODUCTION are skipped on DEV
# Usage: _ask_git_branch <path-to-.env> <path-to-.env.local> <KEY> <default>

_ask_git_branch() {
    local env="$1"
    local env_local="$2"
    local key="$3"
    local default_branch="$4"

    if [[ "$DKZ_ENV" == "DEV" && ("$key" == "DKZ_GIT_BRANCH_STAGING" || "$key" == "DKZ_GIT_BRANCH_PRODUCTION") ]]; then
        return
    fi

    echo -e "\n${CYELLOW}Git branch:${CDEF}"
    read -r -e -p "$key: " -i "$default_branch" branch_value

    if [[ -z "$branch_value" ]]; then
        echo -e "${CRED}Value cannot be empty. Try again...${CDEF}"
        _ask_git_branch "$env" "$env_local" "$key" "$default_branch"
        return
    fi

    echo "$key=$branch_value" >> "$env_local"
    sed -i "s|^$key=.*|$key=$branch_value|" "$env"
}

# _ask_memcached — Handler for DKZ_MEMCACHED_INSTALL
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL != 0: writes 0 silently (Memcached is a backend service)
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL=0: prompts interactively
# Usage: _ask_memcached <path-to-.env> <path-to-.env.local> <default>

_ask_memcached() {
    local env="$1"
    local env_local="$2"
    local default="$3"

    if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
        echo "DKZ_MEMCACHED_INSTALL=0" >> "$env_local"
        sed -i "s|^DKZ_MEMCACHED_INSTALL=.*|DKZ_MEMCACHED_INSTALL=0|" "$env"
        return
    fi

    local raw_value
    raw_value=$(grep "^DKZ_MEMCACHED_INSTALL=" "$env" | head -1)
    raw_value="${raw_value#*=}"

    echo -e "\n${CYELLOW}DKZ_MEMCACHED_INSTALL${CDEF}: $raw_value"
    read -e -p "DKZ_MEMCACHED_INSTALL: " -i "$default" memcached_input

    echo "DKZ_MEMCACHED_INSTALL=$memcached_input" >> "$env_local"
    sed -i "s|^DKZ_MEMCACHED_INSTALL=.*|DKZ_MEMCACHED_INSTALL=$memcached_input|" "$env"
}

# _ask_nginx_basic_auth — Handler for DKZ_NGINX_BASIC_ACCESS_AUTHENTICATION_* keys
# Available on all environments (DEV and PROD) and both project types.
# Username and password can be left empty to disable authentication.
# Usage: _ask_nginx_basic_auth <path-to-.env> <path-to-.env.local> <key> <prefill>

_ask_nginx_basic_auth() {
    local env="$1"
    local env_local="$2"
    local key="$3"
    local prefill="$4"

    echo -e "\n${CYELLOW}${key}${CDEF}: (leave empty to disable Nginx Basic Access Authentication)"
    read -e -p "${key}: " -i "$prefill" nginx_auth_input

    echo "${key}=${nginx_auth_input}" >> "$env_local"
    sed -i "s|^${key}=.*|${key}=${nginx_auth_input}|" "$env"
}

# _ask_adminer_password — Handler for DKZ_ADMINER_PASSWORD
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL != 0: skipped (Adminer is a backend service)
# DEV: skipped (password not needed on local environments)
# PROD + DKZ_PHP_VERSION_INSTALL != 0: prompts with empty default
# Usage: _ask_adminer_password <path-to-.env> <path-to-.env.local>

_ask_adminer_password() {
    local env="$1"
    local env_local="$2"

    if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" || "$DKZ_ENV" == "DEV" ]]; then
        return
    fi

    echo -e "\n${CYELLOW}DKZ_ADMINER_PASSWORD${CDEF}:"
    read -r -s -p "DKZ_ADMINER_PASSWORD: " adminer_input && echo ""

    if [[ -z "$adminer_input" ]]; then
        echo -e "${CRED}Adminer password cannot be empty. Try again...${CDEF}"
        _ask_adminer_password "$env" "$env_local"
        return
    fi

    echo "DKZ_ADMINER_PASSWORD=$adminer_input" >> "$env_local"
}

# _ask_maxmind — Handler for DKZ_MAXMIND_LICENSE_KEY
# DKZ_PHP_SYMFONY_AURORA_INSTALL != 1: writes DKZ_MAXMIND_LICENSE_KEY=0 silently (MaxMind only needed with Aurora)
# DKZ_PHP_SYMFONY_AURORA_INSTALL=1: prompts interactively for the license key
# Usage: _ask_maxmind <path-to-.env> <path-to-.env.local>

_ask_maxmind() {
    local env="$1"
    local env_local="$2"

    # Frontend project (Angular/NodeJS): skip MaxMind entirely — no write to env.local
    if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
        return
    fi

    if [[ "${DKZ_PHP_SYMFONY_AURORA_INSTALL:-0}" != "1" ]]; then
        echo "DKZ_MAXMIND_LICENSE_KEY=0" >> "$env_local"
        sed -i "s|^DKZ_MAXMIND_LICENSE_KEY=.*|DKZ_MAXMIND_LICENSE_KEY=0|" "$env"
        return
    fi

    echo -e "\n${CYELLOW}DKZ_MAXMIND_LICENSE_KEY${CDEF}:"
    read -r -s -p "DKZ_MAXMIND_LICENSE_KEY: " maxmind_input && echo ""

    if [[ -z "$maxmind_input" ]]; then
        echo -e "${CRED}MaxMind license key cannot be empty. Try again...${CDEF}"
        _ask_maxmind "$env" "$env_local"
        return
    fi

    echo "DKZ_MAXMIND_LICENSE_KEY=$maxmind_input" >> "$env_local"
}

# _ask_rabbitmq — Handler for DKZ_RABBITMQ_INSTALL
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL != 0: writes 0 silently (RabbitMQ is a backend service)
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL=0: prompts interactively
# Usage: _ask_rabbitmq <path-to-.env> <path-to-.env.local> <default>

_ask_rabbitmq() {
    local env="$1"
    local env_local="$2"
    local default="$3"

    if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
        echo "DKZ_RABBITMQ_INSTALL=0" >> "$env_local"
        sed -i "s|^DKZ_RABBITMQ_INSTALL=.*|DKZ_RABBITMQ_INSTALL=0|" "$env"
        return
    fi

    local raw_value
    raw_value=$(grep "^DKZ_RABBITMQ_INSTALL=" "$env" | head -1)
    raw_value="${raw_value#*=}"

    echo -e "\n${CYELLOW}DKZ_RABBITMQ_INSTALL${CDEF}: $raw_value"
    read -e -p "DKZ_RABBITMQ_INSTALL: " -i "$default" rabbitmq_input

    echo "DKZ_RABBITMQ_INSTALL=$rabbitmq_input" >> "$env_local"
    sed -i "s|^DKZ_RABBITMQ_INSTALL=.*|DKZ_RABBITMQ_INSTALL=$rabbitmq_input|" "$env"
}

# _ask_mongodb — Handler for DKZ_MONGODB_INSTALL
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL != 0: writes 0 silently (MongoDB is a backend service)
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL=0: prompts interactively
# Usage: _ask_mongodb <path-to-.env> <path-to-.env.local> <default>

_ask_mongodb() {
    local env="$1"
    local env_local="$2"
    local default="$3"

    if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
        echo "DKZ_MONGODB_INSTALL=0" >> "$env_local"
        sed -i "s|^DKZ_MONGODB_INSTALL=.*|DKZ_MONGODB_INSTALL=0|" "$env"
        return
    fi

    local raw_value
    raw_value=$(grep "^DKZ_MONGODB_INSTALL=" "$env" | head -1)
    raw_value="${raw_value#*=}"

    echo -e "\n${CYELLOW}DKZ_MONGODB_INSTALL${CDEF}: $raw_value"
    read -e -p "DKZ_MONGODB_INSTALL: " -i "$default" mongodb_input

    echo "DKZ_MONGODB_INSTALL=$mongodb_input" >> "$env_local"
    sed -i "s|^DKZ_MONGODB_INSTALL=.*|DKZ_MONGODB_INSTALL=$mongodb_input|" "$env"
}

# _ask_ai — Handler for each DKZ_AI_* key individually
# DKZ_AI_CLAUDE_CODE_INSTALL: always prompted (native Linux install, no NodeJS dep)
# DKZ_AI_CODEX_INSTALL / DKZ_AI_GEMINI_INSTALL: require DKZ_NODEJS_INSTALL=1;
#   if NodeJS not installed, written silently with 0
# Usage: _ask_ai <path-to-.env> <path-to-.env.local> <KEY> <default>

_ask_ai() {
    local env="$1"
    local env_local="$2"
    local key="$3"
    local default="$4"

    # Codex and Gemini require NodeJS; Claude Code is NodeJS-independent
    if [[ "$key" != "DKZ_AI_CLAUDE_CODE_INSTALL" && "$DKZ_NODEJS_INSTALL" != "1" ]]; then
        echo "$key=0" >> "$env_local"
        sed -i "s|^$key=.*|$key=0|" "$env"
        return
    fi

    local raw_value
    raw_value=$(grep "^$key=" "$env" | head -1)
    raw_value="${raw_value#*=}"

    echo -e "\n${CYELLOW}$key${CDEF}: $raw_value"
    read -e -p "$key: " -i "$default" ai_input

    echo "$key=$ai_input" >> "$env_local"
    sed -i "s|^$key=.*|$key=$ai_input|" "$env"
}

# _ask_nodejs — Handler for each DKZ_NODEJS_* key individually
# INSTALL=0: writes DKZ_NODEJS_ANGULAR_PORT silently with .env default
# INSTALL=1: prompts for DKZ_NODEJS_ANGULAR_PORT
# Smart default: DKZ_NODEJS_ANGULAR_VERSION_INSTALL != 0 sets DKZ_NODEJS_INSTALL default to 1
# Usage: _ask_nodejs <path-to-.env> <path-to-.env.local> <KEY> <default>

_ask_nodejs() {
    local env="$1"
    local env_local="$2"
    local key="$3"
    local default="$4"

    # If INSTALL=0, write sub-keys silently with defaults
    if [[ "$key" != "DKZ_NODEJS_INSTALL" && "$DKZ_NODEJS_INSTALL" == "0" ]]; then
        echo "$key=$default" >> "$env_local"
        sed -i "s|^$key=.*|$key=$default|" "$env"
        return
    fi

    # Smart default: Angular projects always need NodeJS
    [[ "$key" == "DKZ_NODEJS_INSTALL" && "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]] && default=1

    local raw_value
    raw_value=$(grep "^$key=" "$env" | head -1)
    raw_value="${raw_value#*=}"

    echo -e "\n${CYELLOW}$key${CDEF}: $raw_value"
    read -e -p "$key: " -i "$default" nodejs_input

    # Capture INSTALL value for subsequent sub-key skip logic
    [[ "$key" == "DKZ_NODEJS_INSTALL" ]] && DKZ_NODEJS_INSTALL="$nodejs_input"

    echo "$key=$nodejs_input" >> "$env_local"
    sed -i "s|^$key=.*|$key=$nodejs_input|" "$env"
}

# _ask_certbot — Handler for DKZ_CERTBOT_INSTALL
# DEV: writes 0 silently (certbot not applicable on local environments)
# PROD: prompts interactively
# Usage: _ask_certbot <path-to-.env> <path-to-.env.local> <default>

_ask_certbot() {
    local env="$1"
    local env_local="$2"
    local default="$3"

    if [[ "$DKZ_ENV" == "DEV" ]]; then
        echo "DKZ_CERTBOT_INSTALL=0" >> "$env_local"
        sed -i "s|^DKZ_CERTBOT_INSTALL=.*|DKZ_CERTBOT_INSTALL=0|" "$env"
        return
    fi

    local raw_value
    raw_value=$(grep "^DKZ_CERTBOT_INSTALL=" "$env" | head -1)
    raw_value="${raw_value#*=}"

    echo -e "\n${CYELLOW}DKZ_CERTBOT_INSTALL${CDEF}: $raw_value"
    read -e -p "DKZ_CERTBOT_INSTALL: " -i "$default" certbot_input

    echo "DKZ_CERTBOT_INSTALL=$certbot_input" >> "$env_local"
    sed -i "s|^DKZ_CERTBOT_INSTALL=.*|DKZ_CERTBOT_INSTALL=$certbot_input|" "$env"
}

# _ask_php — Handler for each DKZ_PHP_* key individually
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL != 0: writes DKZ_PHP_VERSION_INSTALL=0 and all other DKZ_PHP_* with .env defaults
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL=0, DKZ_PHP_VERSION_INSTALL=0: writes sub-keys silently with .env defaults
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL=0, DKZ_PHP_VERSION_INSTALL != 0: prompts interactively (xdebug default=1 on DEV)
# DKZ_PHP_SYMFONY_VERSION_INSTALL=0: writes DKZ_PHP_SYMFONY_AURORA_INSTALL and DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL silently with .env defaults
# Usage: _ask_php <path-to-.env> <path-to-.env.local> <KEY> <default>

_ask_php() {
    local env="$1"
    local env_local="$2"
    local key="$3"
    local default="$4"

    if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
        local value="$default"
        [[ "$key" == "DKZ_PHP_VERSION_INSTALL" ]] && value=0
        echo "$key=$value" >> "$env_local"
        sed -i "s|^$key=.*|$key=$value|" "$env"
        return
    fi

    # If DKZ_PHP_VERSION_INSTALL=0, write sub-keys silently with defaults
    if [[ "$key" != "DKZ_PHP_VERSION_INSTALL" && "${DKZ_PHP_VERSION_INSTALL:-0}" == "0" ]]; then
        echo "$key=$default" >> "$env_local"
        sed -i "s|^$key=.*|$key=$default|" "$env"
        return
    fi

    # Smart defaults: xdebug forced on in DEV, forced off (silent) in PROD
    [[ "$key" == "DKZ_PHP_XDEBUG" && "$DKZ_ENV" == "DEV" ]] && default=1
    if [[ "$key" == "DKZ_PHP_XDEBUG" && "$DKZ_ENV" == "PROD" ]]; then
        echo "$key=0" >> "$env_local"
        sed -i "s|^$key=.*|$key=0|" "$env"
        return
    fi

    # DKZ_PHP_VERSION_INSTALL: special prompt — accepts version number or 0
    if [[ "$key" == "DKZ_PHP_VERSION_INSTALL" ]]; then
        # Smart default: pre-fill 8.5 in DEV when no version is configured yet
        [[ "$DKZ_ENV" == "DEV" && "$default" == "0" ]] && default="8.5"

        echo -e "\n${CYELLOW}PHP (EXACT) version to install (0 = skip, e.g. 8.4, 8.5):${CDEF}"
        read -r -e -p "DKZ_PHP_VERSION_INSTALL: " -i "$default" php_input
        if ! [[ "$php_input" =~ ^0$|^[0-9]+\.[0-9]+$ ]]; then
            echo -e "${CRED}Must be 0 or a version number (e.g. 8.5). Try again...${CDEF}"
            _ask_php "$env" "$env_local" "$key" "$default"
            return
        fi
        DKZ_PHP_VERSION_INSTALL="$php_input"
        echo "$key=$php_input" >> "$env_local"
        sed -i "s|^$key=.*|$key=$php_input|" "$env"
        return
    fi

    # Symfony version: special interactive prompt
    if [[ "$key" == "DKZ_PHP_SYMFONY_VERSION_INSTALL" ]]; then
        [[ "$default" == "0" && "${DKZ_PHP_VERSION_INSTALL:-0}" != "0" ]] && default="8.0"
        echo -e "\n${CYELLOW}Symfony (EXACT) version to install (0 = skip, e.g. 7.4 or 8.0):${CDEF}"
        read -r -e -p "DKZ_PHP_SYMFONY_VERSION_INSTALL: " -i "$default" symfony_version
        if ! [[ "$symfony_version" =~ ^0$|^[0-9]+\.[0-9]+$ ]]; then
            echo -e "${CRED}Must be 0 or a version number (e.g. 8.0). Try again...${CDEF}"
            _ask_php "$env" "$env_local" "$key" "$default"
            return
        fi
        DKZ_PHP_SYMFONY_VERSION_INSTALL="$symfony_version"
        echo "$key=$symfony_version" >> "$env_local"
        sed -i "s|^$key=.*|$key=$symfony_version|" "$env"
        return
    fi

    # If DKZ_PHP_SYMFONY_VERSION_INSTALL=0, write Aurora silently with default
    if [[ "$key" == "DKZ_PHP_SYMFONY_AURORA_INSTALL" && "${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" == "0" ]]; then
        DKZ_PHP_SYMFONY_AURORA_INSTALL="$default"
        echo "$key=$default" >> "$env_local"
        sed -i "s|^$key=.*|$key=$default|" "$env"
        return
    fi

    # DKZ_PHP_SYMFONY_AURORA_INSTALL: prompt and capture to shell variable (needed by _ask_maxmind)
    if [[ "$key" == "DKZ_PHP_SYMFONY_AURORA_INSTALL" ]]; then
        # Smart default: pre-fill 1 in DEV when not yet configured
        [[ "$DKZ_ENV" == "DEV" && "$default" == "0" ]] && default="1"

        echo -e "\n${CYELLOW}Install Aurora (MaxMind GeoIP integration)? (0 = no, 1 = yes):${CDEF}"
        read -r -e -p "DKZ_PHP_SYMFONY_AURORA_INSTALL: " -i "$default" aurora_input
        DKZ_PHP_SYMFONY_AURORA_INSTALL="$aurora_input"
        echo "$key=$aurora_input" >> "$env_local"
        sed -i "s|^$key=.*|$key=$aurora_input|" "$env"
        return
    fi

    # If DKZ_PHP_SYMFONY_VERSION_INSTALL=0, write API Platform silently with default
    if [[ "$key" == "DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL" && "${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" == "0" ]]; then
        echo "$key=$default" >> "$env_local"
        sed -i "s|^$key=.*|$key=$default|" "$env"
        return
    fi

    # DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL: prompt with default 4.3 when Symfony is installed
    if [[ "$key" == "DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL" ]]; then
        [[ "$default" == "0" ]] && default="4.3"
        echo -e "\n${CYELLOW}API Platform version to install (0 = skip, e.g. 4.3):${CDEF}"
        read -r -e -p "DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL: " -i "$default" api_platform_input
        if ! [[ "$api_platform_input" =~ ^0$|^[0-9]+\.[0-9]+$ ]]; then
            echo -e "${CRED}Must be 0 or a version number (e.g. 4.3). Try again...${CDEF}"
            _ask_php "$env" "$env_local" "$key" "$default"
            return
        fi
        echo "$key=$api_platform_input" >> "$env_local"
        sed -i "s|^$key=.*|$key=$api_platform_input|" "$env"
        return
    fi

    local raw_value
    raw_value=$(grep "^$key=" "$env" | head -1)
    raw_value="${raw_value#*=}"

    echo -e "\n${CYELLOW}$key${CDEF}: $raw_value"
    read -e -p "$key: " -i "$default" php_input

    echo "$key=$php_input" >> "$env_local"
    sed -i "s|^$key=.*|$key=$php_input|" "$env"
}

# _gen_password — Generates a 24-character random alphanumeric password (A-Z, a-z, 0-9)
_gen_password() {
    head -c 256 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 24
}

# _db_credential_default — Returns the default value for a database credential field
# $1: USERNAME | PASSWORD | DATABASE
_db_credential_default() {
    case "$1" in
        USERNAME|DATABASE) echo "$dockerName" ;;
        PASSWORD)          [[ "$DKZ_ENV" == "DEV" ]] && echo "$dockerName" || _gen_password ;;
    esac
}

# _ask_postgresql — Handler for each DKZ_POSTGRESQL_* key individually
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL != 0: writes DKZ_POSTGRESQL_VERSION_INSTALL=0 and all other keys with .env defaults
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL=0, VERSION_INSTALL=0: writes sub-keys silently with .env defaults
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL=0, VERSION_INSTALL != 0: prompts interactively with smart defaults for credentials/backup
# DKZ_PHP_SYMFONY_VERSION_INSTALL != 0: pre-fills DKZ_POSTGRESQL_VERSION_INSTALL default with 18
# Usage: _ask_postgresql <path-to-.env> <path-to-.env.local> <KEY> <default>

_ask_postgresql() {
    local env="$1"
    local env_local="$2"
    local key="$3"
    local default="$4"

    if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
        local value="$default"
        [[ "$key" == "DKZ_POSTGRESQL_VERSION_INSTALL" ]] && value=0
        echo "$key=$value" >> "$env_local"
        sed -i "s|^$key=.*|$key=$value|" "$env"
        return
    fi

    # If VERSION_INSTALL=0, write sub-keys silently with defaults
    if [[ "$key" != "DKZ_POSTGRESQL_VERSION_INSTALL" && "${DKZ_POSTGRESQL_VERSION_INSTALL:-0}" == "0" ]]; then
        echo "$key=$default" >> "$env_local"
        sed -i "s|^$key=.*|$key=$default|" "$env"
        return
    fi

    # Smart defaults
    if [[ "$key" =~ ^DKZ_POSTGRESQL_(USERNAME|PASSWORD|DATABASE)$ ]]; then
        default="$(_db_credential_default "${BASH_REMATCH[1]}")"
    fi
    [[ "$key" == "DKZ_POSTGRESQL_BACKUP_INTERVAL" && "$DKZ_ENV" == "PROD" ]] && default="1d"
    [[ "$key" == "DKZ_POSTGRESQL_BACKUP_FORMAT" ]] && default="7zip"
    [[ "$key" == "DKZ_POSTGRESQL_VERSION_INSTALL" && "${DKZ_PHP_SYMFONY_VERSION_INSTALL:-0}" != "0" ]] && default="18"

    local pg_input
    if [[ "$key" == "DKZ_POSTGRESQL_VERSION_INSTALL" ]]; then
        echo -e "\n${CYELLOW}PostgreSQL version to install (0 = skip, e.g. 17 or 18):${CDEF}"
        read -r -e -p "DKZ_POSTGRESQL_VERSION_INSTALL: " -i "$default" pg_input
        if ! [[ "$pg_input" =~ ^0$|^[0-9]+$ ]]; then
            echo -e "${CRED}Must be 0 or a version number (e.g. 17). Try again...${CDEF}"
            _ask_postgresql "$env" "$env_local" "$key" "$default"
            return
        fi
    else
        local raw_value
        raw_value=$(grep "^$key=" "$env" | head -1)
        raw_value="${raw_value#*=}"

        echo -e "\n${CYELLOW}$key${CDEF}: $raw_value"
        read -e -p "$key: " -i "$default" pg_input
    fi

    # Capture VERSION_INSTALL value for subsequent sub-key skip logic
    [[ "$key" == "DKZ_POSTGRESQL_VERSION_INSTALL" ]] && DKZ_POSTGRESQL_VERSION_INSTALL="$pg_input"

    echo "$key=$pg_input" >> "$env_local"
    sed -i "s|^$key=.*|$key=$pg_input|" "$env"
}

# _ask_mysql — Handler for each DKZ_MYSQL_* key individually
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL != 0: writes DKZ_MYSQL_VERSION_INSTALL=0 and all other keys with .env defaults
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL=0, VERSION_INSTALL=0: writes sub-keys silently with .env defaults
# DKZ_NODEJS_ANGULAR_VERSION_INSTALL=0, VERSION_INSTALL != 0: prompts interactively with smart defaults for credentials/backup
# Usage: _ask_mysql <path-to-.env> <path-to-.env.local> <KEY> <default>

_ask_mysql() {
    local env="$1"
    local env_local="$2"
    local key="$3"
    local default="$4"

    if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then
        local value="$default"
        [[ "$key" == "DKZ_MYSQL_VERSION_INSTALL" ]] && value=0
        echo "$key=$value" >> "$env_local"
        sed -i "s|^$key=.*|$key=$value|" "$env"
        return
    fi

    # If VERSION_INSTALL=0, write sub-keys silently with defaults
    if [[ "$key" != "DKZ_MYSQL_VERSION_INSTALL" && "${DKZ_MYSQL_VERSION_INSTALL:-0}" == "0" ]]; then
        echo "$key=$default" >> "$env_local"
        sed -i "s|^$key=.*|$key=$default|" "$env"
        return
    fi

    # Smart defaults
    if [[ "$key" =~ ^DKZ_MYSQL_(USERNAME|PASSWORD|DATABASE)$ ]]; then
        default="$(_db_credential_default "${BASH_REMATCH[1]}")"
    fi
    [[ "$key" == "DKZ_MYSQL_BACKUP_INTERVAL" && "$DKZ_ENV" == "PROD" ]] && default="1d"
    [[ "$key" == "DKZ_MYSQL_BACKUP_FORMAT" ]] && default="7zip"

    local mysql_input
    if [[ "$key" == "DKZ_MYSQL_VERSION_INSTALL" ]]; then
        echo -e "\n${CYELLOW}MySQL version to install (0 = skip, e.g. 9):${CDEF}"
        read -r -e -p "DKZ_MYSQL_VERSION_INSTALL: " -i "$default" mysql_input
        if ! [[ "$mysql_input" =~ ^0$|^[0-9]+$ ]]; then
            echo -e "${CRED}Must be 0 or a version number (e.g. 9). Try again...${CDEF}"
            _ask_mysql "$env" "$env_local" "$key" "$default"
            return
        fi
    else
        local raw_value
        raw_value=$(grep "^$key=" "$env" | head -1)
        raw_value="${raw_value#*=}"

        echo -e "\n${CYELLOW}$key${CDEF}: $raw_value"
        read -e -p "$key: " -i "$default" mysql_input
    fi

    # Capture VERSION_INSTALL value for subsequent sub-key skip logic
    [[ "$key" == "DKZ_MYSQL_VERSION_INSTALL" ]] && DKZ_MYSQL_VERSION_INSTALL="$mysql_input"

    echo "$key=$mysql_input" >> "$env_local"
    sed -i "s|^$key=.*|$key=$mysql_input|" "$env"
}

# setup_env_local — Reads .docker/.env, dispatches each KEY to the appropriate
# handler (or a generic prompt), and writes .docker/.env.local

setup_env_local() {
    clear

    local ENV_FILE="$DKZ_DIR/.env"
    local ENV_LOCAL="$DKZ_DIR/.env.local"

    # Ensure .env ends with a newline so the last line is always read
    sed -i -e '$a\' "$ENV_FILE"

    echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo -e "${CYELLOW}Configuring .docker/.env.local ...${CDEF}\n"

    while IFS= read -r -u9 line; do
        # Re-source .env.local so far to pick up values written in previous iterations
        [[ -f "$ENV_LOCAL" ]] && source "$ENV_LOCAL"

        # Skip empty lines and full-line comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*$ || "$line" =~ ^# ]] && continue

        KEY="${line%%=*}"
        RAW_VALUE="${line#*=}"

        # Strip inline comment (everything after ' #') for the clean default
        CLEAN_VALUE="${RAW_VALUE%% #*}"
        # If pipe-separated options (eg: DEV|UAT|PROD), take the first as default
        CLEAN_VALUE="${CLEAN_VALUE%%|*}"

        PREFILL="$CLEAN_VALUE"
        # Don't pre-fill template placeholder values (eg: __DOMAIN__, __PLACEHOLDER__)
        [[ "$PREFILL" =~ ^__[A-Z0-9_]+__$ ]] && PREFILL=""

        # ── Dispatch to dedicated handlers ────────────────────────────────────

        case "$KEY" in
            DKZ_ENV)                                    _ask_env                    "$ENV_FILE" "$ENV_LOCAL";                   continue ;;
            DKZ_NODEJS_ANGULAR_VERSION_INSTALL)                      _ask_angular21              "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_RUN_RESTART)                            _ask_run_restart            "$ENV_FILE" "$ENV_LOCAL";                   continue ;;
            DKZ_DIST)                                   _ask_dist                   "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_SHARED_MEMORY)                          _ask_shared_memory          "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_DOMAIN)                                 _ask_domain                 "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_DOMAINS)                                _ask_domains                "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_NAME)                                   _ask_name                   "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_PORT_PREFIX)                            _ask_port_prefix            "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_SELF_MODIFY)                            _ask_self_modify            "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_SHARED_PORTS)                           _ask_shared_ports           "$ENV_FILE" "$ENV_LOCAL";                   continue ;;
            DKZ_GIT_REPO_URI)                           _ask_git_repo_uri           "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_GIT_BRANCH_*)                           _ask_git_branch             "$ENV_FILE" "$ENV_LOCAL" "$KEY" "$PREFILL"; continue ;;
            DKZ_PHP_*)                                  _ask_php                    "$ENV_FILE" "$ENV_LOCAL" "$KEY" "$PREFILL"; continue ;;
            DKZ_POSTGRESQL_*)                           _ask_postgresql             "$ENV_FILE" "$ENV_LOCAL" "$KEY" "$PREFILL"; continue ;;
            DKZ_MYSQL_*)                                _ask_mysql                  "$ENV_FILE" "$ENV_LOCAL" "$KEY" "$PREFILL"; continue ;;
            DKZ_NGINX_BASIC_ACCESS_AUTHENTICATION_*)    _ask_nginx_basic_auth       "$ENV_FILE" "$ENV_LOCAL" "$KEY" "$PREFILL"; continue ;;
            DKZ_MEMCACHED_INSTALL)                      _ask_memcached              "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_MONGODB_INSTALL)                        _ask_mongodb                "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_RABBITMQ_INSTALL)                       _ask_rabbitmq               "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_ADMINER_PASSWORD)                       _ask_adminer_password       "$ENV_FILE" "$ENV_LOCAL";                   continue ;;
            DKZ_MAXMIND_LICENSE_KEY)                    _ask_maxmind                "$ENV_FILE" "$ENV_LOCAL";                   continue ;;
            DKZ_CERTBOT_INSTALL)                        _ask_certbot                "$ENV_FILE" "$ENV_LOCAL" "$PREFILL";        continue ;;
            DKZ_NODEJS_*)                               _ask_nodejs                 "$ENV_FILE" "$ENV_LOCAL" "$KEY" "$PREFILL"; continue ;;
            DKZ_AI_*)                                   _ask_ai                     "$ENV_FILE" "$ENV_LOCAL" "$KEY" "$PREFILL"; continue ;;
        esac
        # ── Generic prompt ─────────────────────────────────────────────────────

        echo -e "\n${CYELLOW}$KEY${CDEF}: $RAW_VALUE"
        read -e -p "$KEY: " -i "$PREFILL" USER_INPUT
        VALUE="$USER_INPUT"

        echo "$KEY=$VALUE" >> "$ENV_LOCAL"
        sed -i "s|^$KEY=.*|$KEY=$VALUE|" "$ENV_FILE"

    done 9< "$ENV_FILE"

    echo -e "\n${CGREEN}.docker/.env.local created.${CDEF}"
}

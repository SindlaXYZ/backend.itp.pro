# syntax = docker/dockerfile:experimental

# https://hub.docker.com/_/ubuntu
# https://hub.docker.com/_/debian
ARG DKZ_DIST
FROM ${DKZ_DIST}

SHELL ["/bin/bash", "-c"]

LABEL maintainer="Sindla"
LABEL version="2026.04.01.0750"
LABEL description="Dockraft"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#   ARG are only available during the build of a Docker image (RUN, etc)
#   ENV are available inside container (see `printenv` command) BUT ARE NOT available inside cron jobs
#   COPY any dir/files copied under /srv/$DKZ_DOMAIN will be deleted/overwritten with DOCKER RUN (volume mount)
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

ARG DKZ_ENV
ENV DKZ_ENV=$DKZ_ENV

ARG DKZ_DOMAIN
ENV DKZ_DOMAIN=$DKZ_DOMAIN

ARG DKZ_DOMAINS=""
ENV DKZ_DOMAINS=$DKZ_DOMAINS

ARG DKZ_GIT_REPO_URI
ENV DKZ_GIT_REPO_URI=$DKZ_GIT_REPO_URI

ARG DKZ_NGINX_INSTALL=1
ENV DKZ_NGINX_INSTALL=$DKZ_NGINX_INSTALL

ARG DKZ_GIT_BRANCH_PRODUCTION="main"
ENV DKZ_GIT_BRANCH_PRODUCTION=$DKZ_GIT_BRANCH_PRODUCTION

ARG DKZ_NODEJS_INSTALL=0
ENV DKZ_NODEJS_INSTALL=$DKZ_NODEJS_INSTALL

ARG DKZ_NODEJS_ANGULAR_VERSION_INSTALL=0
ENV DKZ_NODEJS_ANGULAR_VERSION_INSTALL=$DKZ_NODEJS_ANGULAR_VERSION_INSTALL

ARG DKZ_NODEJS_ANGULAR_PORT=4000
ENV DKZ_NODEJS_ANGULAR_PORT=$DKZ_NODEJS_ANGULAR_PORT

ARG DKZ_PORT80=80

ARG DKZ_PHP_VERSION_INSTALL=0
ENV DKZ_PHP_VERSION_INSTALL=$DKZ_PHP_VERSION_INSTALL

ARG DKZ_PHP_SYMFONY_VERSION_INSTALL=0
ENV DKZ_PHP_SYMFONY_VERSION_INSTALL=$DKZ_PHP_SYMFONY_VERSION_INSTALL

ARG DKZ_PHP_SYMFONY_AURORA_INSTALL=0
ENV DKZ_PHP_SYMFONY_AURORA_INSTALL=$DKZ_PHP_SYMFONY_AURORA_INSTALL

ARG DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL=0
ENV DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL=$DKZ_PHP_SYMFONY_API_PLATFORM_VERSION_INSTALL

ARG DKZ_PHP_XDEBUG=0
ENV DKZ_PHP_XDEBUG=$DKZ_PHP_XDEBUG

ARG DKZ_POSTGRESQL_VERSION_INSTALL=0
ENV DKZ_POSTGRESQL_VERSION_INSTALL=$DKZ_POSTGRESQL_VERSION_INSTALL

ARG DKZ_POSTGRESQL_USERNAME=""
ENV DKZ_POSTGRESQL_USERNAME=$DKZ_POSTGRESQL_USERNAME

ARG DKZ_POSTGRESQL_DATABASE=""
ENV DKZ_POSTGRESQL_DATABASE=$DKZ_POSTGRESQL_DATABASE

ARG DKZ_MYSQL_VERSION_INSTALL=0
ENV DKZ_MYSQL_VERSION_INSTALL=$DKZ_MYSQL_VERSION_INSTALL

ARG DKZ_AI_CODEX_INSTALL=0
ENV DKZ_AI_CODEX_INSTALL=$DKZ_AI_CODEX_INSTALL

ARG DKZ_AI_GEMINI_INSTALL=0
ENV DKZ_AI_GEMINI_INSTALL=$DKZ_AI_GEMINI_INSTALL

ARG DKZ_AI_CLAUDE_CODE_INSTALL=0
ENV DKZ_AI_CLAUDE_CODE_INSTALL=$DKZ_AI_CLAUDE_CODE_INSTALL

# ----------------------------------------------------------------------------------------------------------------------

WORKDIR /
USER root

RUN if [ -z "$DKZ_ENV" ] || [ -z "$DKZ_DOMAIN" ]; then \
        echo "ERROR: DKZ_ENV and DKZ_DOMAIN build args are required" && exit 1; \
    fi

# ----------------------------------------------------------------------------------------------------------------------
# Install essential packages + supervisor (required by CMD)
# ----------------------------------------------------------------------------------------------------------------------

RUN apt-get -y update && \
    apt-get -y install --no-install-recommends \
        ca-certificates \
        cron \
        curl \
        git \
        nano \
        nginx \
        htop \
        wget \
        p7zip-full \
        supervisor \
        rsync \
        tree \
        jq && \
    rm -rf /var/lib/apt/lists/*

# ----------------------------------------------------------------------------------------------------------------------
# yq (v4.52.5)
# ----------------------------------------------------------------------------------------------------------------------

RUN VERSION=v4.52.5 BINARY=yq_linux_amd64 && wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz -O - | tar xz && mv ${BINARY} /usr/bin/yq

# ----------------------------------------------------------------------------------------------------------------------
# /root/sindla/ — runtime directory for the boot-init timestamp file.
# boot-init.sh writes $(date +%s) here; healthcheck.sh reads it to track
# whether boot initialization is still in progress (10-min grace period).
# Scripts other than boot-init.sh are served from /srv/${DKZ_DOMAIN}/.docker/container/scripts/ at runtime.
# ----------------------------------------------------------------------------------------------------------------------

RUN mkdir -p /root/sindla/

# ----------------------------------------------------------------------------------------------------------------------
# GitHub token for 'dockraft' — stored at /root/.dockraft-token (chmod 600, root-only).
# Passed via BuildKit secret: never written to image layers or visible in docker history.
# If .docker/.github-token does not exist the build proceeds without a token
# (dockraft will still work for public repositories).
# ----------------------------------------------------------------------------------------------------------------------

RUN --mount=type=secret,id=DKZ_GITHUB_TOKEN \
    if [ -s /run/secrets/DKZ_GITHUB_TOKEN ]; then \
        cp /run/secrets/DKZ_GITHUB_TOKEN /root/.dockraft-token && \
        chmod 600 /root/.dockraft-token; \
    fi

# ----------------------------------------------------------------------------------------------------------------------
# supervisord config — keeps the container alive; includes the boot-init program
# Additional programs are added by downstream Dockerfile sections
# ----------------------------------------------------------------------------------------------------------------------

RUN mkdir -p /etc/supervisor/conf.d /var/log/supervisor
COPY container/etc/supervisor/conf.d/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# ----------------------------------------------------------------------------------------------------------------------
# boot-init.sh — the only script baked into /etc/dockraft/scripts/.
# It runs once on first container start (via supervisord [program:boot-init]), then self-deletes.
# All other scripts (lib.sh, colors.sh, angular.sh, boot.sh, healthcheck.sh, motd.sh) are served
# at runtime from /srv/${DKZ_DOMAIN}/.docker/container/scripts/:
#   DEV:  /srv/${DKZ_DOMAIN}/ is volume-mounted.
#   PROD: /srv/${DKZ_DOMAIN}/ contains the git-cloned project (built during image build).
# bash.bashrc sources motd.sh on every interactive shell (i.e., on `docker exec … bash`).
# ----------------------------------------------------------------------------------------------------------------------

COPY container/scripts/boot-init.sh /etc/dockraft/scripts/boot-init.sh
RUN chmod +x /etc/dockraft/scripts/boot-init.sh && \
    echo "" >> /etc/bash.bashrc && \
    echo "# Dockraft:" >> /etc/bash.bashrc && \
    echo "cd /srv/\${DKZ_DOMAIN} 2>/dev/null || true" >> /etc/bash.bashrc && \
    echo "source /srv/\${DKZ_DOMAIN}/.docker/container/scripts/motd.sh 2>/dev/null || true" >> /etc/bash.bashrc

# ----------------------------------------------------------------------------------------------------------------------
# Nginx — copy site config templates and generate /etc/nginx/sites-available/*.conf at build time.
# Template selection:
#   DKZ_PHP_VERSION_INSTALL != 0           → php/__DOMAIN__.conf.dist
#   DKZ_NODEJS_ANGULAR_VERSION_INSTALL != 0 + DEV       → html/__DOMAIN__.conf.dist       (proxy to ng serve)
#   DKZ_NODEJS_ANGULAR_VERSION_INSTALL != 0 + PROD      → html/__DOMAIN__.ssr.conf.dist   (proxy to node server.mjs)
# Placeholders replaced: __DOMAIN__, __PORT80__, __WEB_ROOT__, __ANGULAR_SSR_PORT__
# Secondary domains (comma-separated DKZ_DOMAINS) lose the `default_server` flag.
# DKZ_PHP_VERSION_INSTALL != 0: also generates adminer.<domain>.conf
# ----------------------------------------------------------------------------------------------------------------------

COPY container/etc/nginx/sites-available/ /etc/nginx/sites-available/

RUN set -e; \
    if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" != "0" ]]; then \
        _tmpl="/etc/nginx/sites-available/php/__DOMAIN__.conf.dist"; \
    elif [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]] && [[ "$DKZ_ENV" != "DEV" ]]; then \
        _tmpl="/etc/nginx/sites-available/html/__DOMAIN__.ssr.conf.dist"; \
    else \
        _tmpl="/etc/nginx/sites-available/html/__DOMAIN__.conf.dist"; \
    fi; \
    _domains="$DKZ_DOMAIN"; \
    if [[ -n "$DKZ_DOMAINS" ]]; then \
        IFS=',' read -ra _extra <<< "$DKZ_DOMAINS"; \
        for _d in "${_extra[@]}"; do \
            _d="${_d// /}"; \
            if [[ -n "$_d" && "$_d" != "$DKZ_DOMAIN" ]]; then \
                _domains="$_domains $_d"; \
            fi; \
        done; \
    fi; \
    _first=true; \
    for _domain in $_domains; do \
        _dest="/etc/nginx/sites-available/${_domain}.conf"; \
        cp -f "$_tmpl" "$_dest"; \
        sed -i -e "s/__DOMAIN__/${_domain}/g" -e "s/__PORT80__/${DKZ_PORT80}/g" "$_dest"; \
        if [[ "$_first" == "false" ]]; then \
            sed -i -e "s/80 default_server;/80;/g" "$_dest"; \
        fi; \
        if [[ "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then \
            sed -i -e "s|__WEB_ROOT__|/srv/${_domain}/dist/${_domain}/browser|g" -e "s|__ANGULAR_SSR_PORT__|${DKZ_NODEJS_ANGULAR_PORT}|g" "$_dest"; \
        fi; \
        _first=false; \
    done; \
    if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" != "0" ]]; then \
        cp -f "/etc/nginx/sites-available/php/adminer.__DOMAIN__.conf.dist" "/etc/nginx/sites-available/adminer.${DKZ_DOMAIN}.conf"; \
        sed -i -e "s/__DOMAIN__/${DKZ_DOMAIN}/g" -e "s/__PORT80__/${DKZ_PORT80}/g" "/etc/nginx/sites-available/adminer.${DKZ_DOMAIN}.conf"; \
    fi; \
    rm -rf /etc/nginx/sites-available/php/ /etc/nginx/sites-available/html/; \
    rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default; \
    mkdir -p /etc/nginx/sites-enabled; \
    for _conf in /etc/nginx/sites-available/*.conf; do \
        ln -sf "$_conf" "/etc/nginx/sites-enabled/$(basename "$_conf")"; \
    done

# ----------------------------------------------------------------------------------------------------------------------
# PHP + PHP-FPM — installed when DKZ_PHP_VERSION_INSTALL != 0 (value is the PHP version, e.g. 8.5).
# Uses Sury repository for Debian (https://packages.sury.org/php/).
# Composer is installed globally at /usr/local/bin/composer.
# Xdebug is installed in a separate layer to allow skipping it for PROD images.
# User/DB creation for PostgreSQL is deferred to boot-init.sh (password is a runtime secret).
# ----------------------------------------------------------------------------------------------------------------------

RUN set -e; \
    if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" == "0" ]]; then exit 0; fi; \
    curl -fsSL https://packages.sury.org/php/apt.gpg -o /usr/share/keyrings/sury-php.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(. /etc/os-release && echo $VERSION_CODENAME) main" > /etc/apt/sources.list.d/sury-php.list && \
    apt-get -y update && \
    apt-get -y install --no-install-recommends \
        php${DKZ_PHP_VERSION_INSTALL} \
        php${DKZ_PHP_VERSION_INSTALL}-apcu \
        php${DKZ_PHP_VERSION_INSTALL}-bcmath \
        php${DKZ_PHP_VERSION_INSTALL}-curl \
        php${DKZ_PHP_VERSION_INSTALL}-dom \
        php${DKZ_PHP_VERSION_INSTALL}-fpm \
        php${DKZ_PHP_VERSION_INSTALL}-gd \
        php${DKZ_PHP_VERSION_INSTALL}-gmp \
        php${DKZ_PHP_VERSION_INSTALL}-intl \
        php${DKZ_PHP_VERSION_INSTALL}-mbstring \
        php${DKZ_PHP_VERSION_INSTALL}-pgsql \
        php${DKZ_PHP_VERSION_INSTALL}-xml \
        php${DKZ_PHP_VERSION_INSTALL}-xmlwriter \
        php${DKZ_PHP_VERSION_INSTALL}-zip && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    rm -rf /var/lib/apt/lists/* && \
    sed -i "s|^listen = .*|listen = 127.0.0.1:9000|" "/etc/php/${DKZ_PHP_VERSION_INSTALL}/fpm/pool.d/www.conf"

RUN set -e; \
    if [[ "${DKZ_PHP_VERSION_INSTALL:-0}" == "0" || "$DKZ_PHP_XDEBUG" != "1" ]]; then exit 0; fi; \
    apt-get -y update && \
    apt-get -y install --no-install-recommends php${DKZ_PHP_VERSION_INSTALL}-xdebug && \
    rm -rf /var/lib/apt/lists/*

# ----------------------------------------------------------------------------------------------------------------------
# PostgreSQL — installed when DKZ_POSTGRESQL_VERSION_INSTALL != 0.
# Uses official PostgreSQL apt repo (apt.postgresql.org).
# pg_hba.conf: DEV → accepts remote connections; PROD → no remote connections.
# User and database creation is deferred to boot-init.sh because DKZ_POSTGRESQL_PASSWORD
# is a runtime secret and must never appear in image layers.
# ----------------------------------------------------------------------------------------------------------------------

RUN set -e; \
    if [[ "${DKZ_POSTGRESQL_VERSION_INSTALL:-0}" == "0" ]]; then exit 0; fi; \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o /usr/share/keyrings/postgresql.asc && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql.asc] http://apt.postgresql.org/pub/repos/apt $(. /etc/os-release && echo $VERSION_CODENAME)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get -y update && \
    apt-get -y install --no-install-recommends postgresql-${DKZ_POSTGRESQL_VERSION_INSTALL} postgresql-client-${DKZ_POSTGRESQL_VERSION_INSTALL} && \
    rm -rf /var/lib/apt/lists/* && \
    pg_lsclusters -h | grep -q "^${DKZ_POSTGRESQL_VERSION_INSTALL} main" || pg_createcluster "${DKZ_POSTGRESQL_VERSION_INSTALL}" main

RUN set -e; \
    if [[ "${DKZ_POSTGRESQL_VERSION_INSTALL:-0}" == "0" ]]; then exit 0; fi; \
    PG_HBA="/etc/postgresql/${DKZ_POSTGRESQL_VERSION_INSTALL}/main/pg_hba.conf" && \
    PG_CONF="/etc/postgresql/${DKZ_POSTGRESQL_VERSION_INSTALL}/main/postgresql.conf" && \
    printf "local   all             postgres                                peer\n" > "$PG_HBA" && \
    printf "local   all             root                                    peer\n" >> "$PG_HBA" && \
    printf "local   all             all                                     md5\n"  >> "$PG_HBA" && \
    if [[ "$DKZ_ENV" == "DEV" ]]; then \
        printf "host    all             all                0.0.0.0/0            md5\n" >> "$PG_HBA" && \
        printf "\nlisten_addresses = '*'\n" >> "$PG_CONF"; \
    else \
        printf "\nlisten_addresses = ''\n" >> "$PG_CONF"; \
    fi

# ----------------------------------------------------------------------------------------------------------------------
# Node.js via nvm — installed when DKZ_NODEJS_INSTALL=1 or DKZ_NODEJS_ANGULAR_VERSION_INSTALL != 0.
# Node 22 LTS. nvm is sourced in /etc/profile.d/nvm.sh (login shells) and
# explicitly sourced in container scripts (angular.sh, boot.sh) for non-login shells.
# ----------------------------------------------------------------------------------------------------------------------

# Switch to bash for all subsequent RUN steps — nvm requires bash (source builtin not available in dash/sh)
SHELL ["/bin/bash", "-c"]

RUN set -e; \
    if [[ "$DKZ_NODEJS_INSTALL" == "1" || "${DKZ_NODEJS_ANGULAR_VERSION_INSTALL:-0}" != "0" ]]; then \
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash; \
        export NVM_DIR="/root/.nvm"; \
        . "$NVM_DIR/nvm.sh"; \
        nvm install 22; \
        nvm alias default 22; \
        echo 'export NVM_DIR="/root/.nvm"' > /etc/profile.d/nvm.sh; \
        echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> /etc/profile.d/nvm.sh; \
    fi

# ----------------------------------------------------------------------------------------------------------------------
# AI tools — Codex (OpenAI), Gemini (Google), Claude Code (Anthropic).
# Codex and Gemini require Node.js (DKZ_NODEJS_INSTALL=1); Claude Code is a native binary install.
# ----------------------------------------------------------------------------------------------------------------------

RUN set -e; \
    if [[ "${DKZ_NODEJS_INSTALL:-0}" != "1" || "${DKZ_AI_CODEX_INSTALL:-0}" == "0" ]]; then exit 0; fi; \
    export NVM_DIR="/root/.nvm"; \
    . "$NVM_DIR/nvm.sh"; \
    npm i -g @openai/codex@latest && \
    apt-get -y update && \
    apt-get -y install --no-install-recommends lsof ripgrep && \
    rm -rf /var/lib/apt/lists/*

RUN set -e; \
    if [[ "${DKZ_NODEJS_INSTALL:-0}" != "1" || "${DKZ_AI_GEMINI_INSTALL:-0}" == "0" ]]; then exit 0; fi; \
    export NVM_DIR="/root/.nvm"; \
    . "$NVM_DIR/nvm.sh"; \
    npm i -g @google/gemini-cli

RUN set -e; \
    if [[ "${DKZ_AI_CLAUDE_CODE_INSTALL:-0}" == "0" ]]; then exit 0; fi; \
    curl -fsSL https://claude.ai/install.sh | bash && \
    echo 'export PATH="$HOME/.local/bin:${PATH}"' >> /etc/profile.d/claude.sh && \
    echo "source /etc/profile.d/claude.sh" >> /etc/bash.bashrc

# ----------------------------------------------------------------------------------------------------------------------
# PROD: clone project repository into /srv/${DKZ_DOMAIN}/ at image build time.
# Skipped in DEV — the project root is volume-mounted at container start.
# SSH URIs (git@github.com:org/repo.git) are converted to HTTPS automatically.
# The GitHub token is consumed via BuildKit secret so it never appears in image layers.
# Falls back to /root/.dockraft-token (written above) if the secret is unavailable.
# ----------------------------------------------------------------------------------------------------------------------

RUN --mount=type=secret,id=DKZ_GITHUB_TOKEN \
    set -e; \
    if [[ "$DKZ_ENV" == "DEV" ]]; then exit 0; fi; \
    if [[ -z "$DKZ_GIT_REPO_URI" ]]; then echo "WARN: DKZ_GIT_REPO_URI is empty — skipping project clone"; exit 0; fi; \
    _token=""; \
    if [[ -s /run/secrets/DKZ_GITHUB_TOKEN ]]; then \
        _token=$(cat /run/secrets/DKZ_GITHUB_TOKEN); \
    elif [[ -f /root/.dockraft-token && -s /root/.dockraft-token ]]; then \
        _token=$(cat /root/.dockraft-token); \
    fi; \
    _uri="$DKZ_GIT_REPO_URI"; \
    if [[ "$_uri" =~ ^git@github\.com[^:]*:(.+)$ ]]; then \
        _path="${BASH_REMATCH[1]}"; \
        if [[ -n "$_token" ]]; then \
            _uri="https://${_token}@github.com/${_path}"; \
        else \
            _uri="https://github.com/${_path}"; \
        fi; \
    elif [[ "$_uri" =~ ^https://github\.com/(.+)$ ]] && [[ -n "$_token" ]]; then \
        _uri="https://${_token}@github.com/${BASH_REMATCH[1]}"; \
    fi; \
    mkdir -p "/srv/${DKZ_DOMAIN}"; \
    git clone --depth=1 --branch "${DKZ_GIT_BRANCH_PRODUCTION}" "$_uri" "/srv/${DKZ_DOMAIN}/"

# ----------------------------------------------------------------------------------------------------------------------
# Copy .env.local into the project directory so container scripts can source it in PROD.
# In DEV the volume mount shadows this file — no conflict.
# ----------------------------------------------------------------------------------------------------------------------

COPY .env.local /srv/${DKZ_DOMAIN}/.docker/.env.local

# ----------------------------------------------------------------------------------------------------------------------
# Cleanup
# ----------------------------------------------------------------------------------------------------------------------

RUN apt-get -y autoremove && \
    apt-get -y autoclean && \
    apt-get -y clean && \
    rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# ----------------------------------------------------------------------------------------------------------------------

# Health check — runs healthcheck.sh from the project directory (volume-mounted in DEV; git-cloned in PROD)
# DKZ_DOMAIN is a Docker ENV variable and expands correctly at runtime.
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD bash /srv/${DKZ_DOMAIN}/.docker/container/scripts/healthcheck.sh

# ----------------------------------------------------------------------------------------------------------------------

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

FROM codercom/code-server:latest

ARG USER_UID=1000
ARG USER_GID=1000
ARG PHP_VERSION=8.3
ARG NODE_MAJOR=22

# --- Root operations: UID/GID adjustment and system packages ---
USER root

# Adjust coder user/group to match host UID/GID
RUN groupmod -g ${USER_GID} coder \
    && usermod -u ${USER_UID} -g ${USER_GID} coder \
    && chown -R ${USER_UID}:${USER_GID} /home/coder

# System prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    gnupg \
    lsb-release \
    ca-certificates \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Add Ondrej Sury PHP repository (Debian variant)
RUN curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
    > /etc/apt/sources.list.d/sury-php.list

# Install PHP and extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-xdebug \
    && rm -rf /var/lib/apt/lists/*

# Install Composer via official installer
RUN curl -fsSL https://getcomposer.org/installer | php -- \
    --install-dir=/usr/local/bin --filename=composer

# Add NodeSource repository
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -

# Install Node.js and yarn
RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    && npm install -g yarn \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3 and pip
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Install Drush Launcher
RUN curl -fsSL https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar \
    -o /usr/local/bin/drush \
    && chmod +x /usr/local/bin/drush

# --- Switch to coder user for extensions and config ---
USER coder

# Configure npm global prefix for coder user (avoids needing root for npm install -g)
RUN mkdir -p /home/coder/.npm-global \
    && npm config set prefix /home/coder/.npm-global \
    && echo 'export PATH="/home/coder/.npm-global/bin:$PATH"' >> /home/coder/.bashrc
ENV PATH="/home/coder/.npm-global/bin:${PATH}"

# Install Claude Code globally as coder user
RUN npm install -g @anthropic-ai/claude-code

# Pre-create directories to prevent bind-mounts from creating them as directories
RUN mkdir -p /home/coder/.local/share/code-server/User \
    && mkdir -p /home/coder/.claude \
    && touch /home/coder/.claude.json

# Install VS Code extensions from extensions.txt
COPY extensions.txt /home/coder/extensions.txt
RUN failed_exts=""; \
    while IFS= read -r ext || [ -n "$ext" ]; do \
      ext=$(echo "$ext" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//'); \
      [ -z "$ext" ] && continue; \
      if ! code-server --install-extension "$ext"; then \
        echo "Failed to install VS Code extension: $ext" >&2; \
        failed_exts="${failed_exts} $ext"; \
      fi; \
    done < /home/coder/extensions.txt; \
    if [ -n "$failed_exts" ]; then \
      echo "One or more VS Code extensions failed to install:${failed_exts}" >&2; \
      exit 1; \
    fi

# Copy entrypoint script
COPY --chown=coder:coder entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /home/coder/code

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["code-server", "--bind-addr", "0.0.0.0:8080", "."]

# Codex Container Dockerfile
# Minimal Alpine Linux container with Node.js for OpenAI Codex

FROM alpine:3.19

ARG CODEX_VERSION=dev

# Container metadata
LABEL maintainer="codex-container"
LABEL description="Isolated environment for OpenAI Codex"
LABEL version="${CODEX_VERSION}"

# Install essential packages
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    docker-cli \
    git \
    jq \
    nodejs \
    npm \
    openssh-client \
    python3 \
    py3-pip \
    pipx \
    shadow \
    sudo \
    tzdata \
    build-base \
    pkgconf \
    linux-headers

# Create non-root user with sudo capabilities
RUN addgroup -g 1000 codex && \
    adduser -D -u 1000 -G codex -s /bin/bash codex && \
    echo "codex ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/codex/.npm-global && \
    mkdir -p /home/codex/.config && \
    mkdir -p /workspace && \
    mkdir -p /config

# Configure npm for global installations
ENV NPM_CONFIG_PREFIX=/home/codex/.npm-global
ENV PIPX_HOME=/config/pipx
ENV PIPX_BIN_DIR=/config/pipx/bin
ENV PIP_CACHE_DIR=/config/pip-cache
ENV PATH=/home/codex/.npm-global/bin:/config/pipx/bin:$PATH

# Create .codex directory with proper permissions
RUN mkdir -p /home/codex/.codex && \
    chown -R codex:codex /home/codex/.codex && \
    chmod 755 /home/codex/.codex

# Set up workspace and config volumes
VOLUME ["/workspace", "/config"]

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN mkdir -p /usr/local/share/codex-container
COPY codex.config.toml /usr/local/share/codex-container/default.config.toml

# Install OpenAI Codex globally
# Note: Installing with --force to handle any potential conflicts
RUN npm config set prefix /home/codex/.npm-global && \
    npm install -g @openai/codex --force || \
    echo "Note: @openai/codex package may not exist or require authentication"

# Install additional useful global npm packages
RUN npm install -g \
    typescript \
    ts-node \
    nodemon \
    prettier \
    eslint \
    npm-check-updates

# Set ownership
RUN chown -R codex:codex /home/codex && \
    chown -R codex:codex /workspace && \
    chown -R codex:codex /config && \
    chmod -R 755 /home/codex

# Switch to non-root user
USER codex
WORKDIR /workspace

# Set environment variables
ENV NODE_ENV=production
ENV CODEX_CONTAINER=true
ENV HOME=/home/codex
ENV CONFIG_DIR=/config

# Default entrypoint and command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]

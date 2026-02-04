#!/usr/bin/env bash
# Entrypoint script for Codex Container
# Handles user ID mapping and environment setup

set -euo pipefail

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

: "${USER_UID:=}"
: "${USER_GID:=}"
: "${ALLOW_SUDO:=}"
: "${CODEX_GIT_NAME:=}"
: "${CODEX_GIT_EMAIL:=}"
: "${CODEX_SSH_PERSIST:=}"
: "${CODEX_SSH_SEED_HOSTS:=}"

is_mountpoint() {
    local path="$1"
    # Busybox doesn't always have mountpoint(1); use /proc/mounts.
    # Match exact mount target (space-delimited).
    grep -qs " $(printf '%s' "$path" | sed 's/ /\\040/g') " /proc/mounts
}

can_sudo() {
    if [ "$ALLOW_SUDO" != "true" ]; then
        return 1
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        return 1
    fi
    if sudo -n true >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

is_root() {
    [ "$(id -u)" -eq 0 ]
}

# Function to setup user permissions
setup_user() {
    if [ -n "$USER_UID" ] && [ -n "$USER_GID" ]; then
        if [ "$USER_UID" != "1000" ] || [ "$USER_GID" != "1000" ]; then
            if is_root; then
                echo -e "${YELLOW}Adjusting user permissions...${NC}"
                usermod -u "$USER_UID" codex 2>/dev/null || true
                groupmod -g "$USER_GID" codex 2>/dev/null || true
                chown -R codex:codex /home/codex 2>/dev/null || true

                # Fix .codex directory permissions specifically (skip if it is a mount)
                if [ -d /home/codex/.codex ] && ! is_mountpoint /home/codex/.codex; then
                    chown -R "$USER_UID:$USER_GID" /home/codex/.codex 2>/dev/null || true
                    chmod -R 755 /home/codex/.codex 2>/dev/null || true
                fi
            elif can_sudo; then
                echo -e "${YELLOW}Adjusting user permissions...${NC}"
                sudo usermod -u "$USER_UID" codex 2>/dev/null || true
                sudo groupmod -g "$USER_GID" codex 2>/dev/null || true
                sudo chown -R codex:codex /home/codex 2>/dev/null || true

                # Fix .codex directory permissions specifically (skip if it is a mount)
                if [ -d /home/codex/.codex ] && ! is_mountpoint /home/codex/.codex; then
                    sudo chown -R "$USER_UID:$USER_GID" /home/codex/.codex 2>/dev/null || true
                    sudo chmod -R 755 /home/codex/.codex 2>/dev/null || true
                fi
            fi
        fi
    fi
}

# Function to initialize configuration
init_config() {
    # Ensure /config exists and base structure is present
    mkdir -p /config /config/npm /config/codex /config/history /config/pipx /config/pip-cache /config/git 2>/dev/null || true
    if is_root; then
        if [ -n "$USER_UID" ] && [ -n "$USER_GID" ]; then
            chown -R "$USER_UID:$USER_GID" /config 2>/dev/null || true
        else
            chown -R codex:codex /config 2>/dev/null || true
        fi
    fi

    export PIPX_HOME=/config/pipx
    export PIPX_BIN_DIR=/config/pipx/bin
    export PIP_CACHE_DIR=/config/pip-cache
    mkdir -p "$PIPX_BIN_DIR" 2>/dev/null || true

    export GIT_CONFIG_GLOBAL=/config/git/gitconfig
    mkdir -p /config/git 2>/dev/null || true
    if [ ! -f /config/git/gitconfig ]; then
        touch /config/git/gitconfig 2>/dev/null || true
        chmod 600 /config/git/gitconfig 2>/dev/null || true
    fi

    # Check if this is first run
    if [ ! -f /config/.initialized ]; then
        echo -e "${GREEN}First run detected. Initializing configuration...${NC}"

        # Create marker file early
        touch /config/.initialized

        # Link npm config
        if [ -L /home/codex/.npm ]; then
            true
        elif [ -e /home/codex/.npm ]; then
            rm -rf /home/codex/.npm 2>/dev/null || true
        fi
        ln -s /config/npm /home/codex/.npm

        # Link .codex directory (persist to /config/codex) unless host-mounted
        if is_mountpoint /home/codex/.codex; then
            true
        else
            if [ -L /home/codex/.codex ]; then
                true
            elif [ -e /home/codex/.codex ]; then
                rm -rf /config/codex 2>/dev/null || true
                mv /home/codex/.codex /config/codex 2>/dev/null || true
            fi

            mkdir -p /config/codex
            rm -rf /home/codex/.codex 2>/dev/null || true
            ln -s /config/codex /home/codex/.codex
        fi

        # Install default Codex config.toml if missing
        if [ ! -f /config/codex/config.toml ] && [ -f /usr/local/share/codex-container/default.config.toml ]; then
            cp /usr/local/share/codex-container/default.config.toml /config/codex/config.toml
            echo -e "${BLUE}Default Codex config.toml created at /config/codex/config.toml${NC}"
        fi

        # Persist bash history (quality-of-life)
        if [ -L /home/codex/.bash_history ]; then
            true
        elif [ -e /home/codex/.bash_history ]; then
            cp /home/codex/.bash_history /config/history/bash_history 2>/dev/null || true
            rm -f /home/codex/.bash_history 2>/dev/null || true
        fi
        touch /config/history/bash_history 2>/dev/null || true
        rm -f /home/codex/.bash_history 2>/dev/null || true
        ln -s /config/history/bash_history /home/codex/.bash_history

        echo -e "${GREEN}Configuration initialized${NC}"
    fi

    # Ensure persistent directories/symlinks exist even after first run
    mkdir -p /config/npm /config/codex /config/history /config/pipx /config/pip-cache /config/git 2>/dev/null || true

    if [ ! -L /home/codex/.npm ]; then
        rm -rf /home/codex/.npm 2>/dev/null || true
        ln -s /config/npm /home/codex/.npm
    fi

    if ! is_mountpoint /home/codex/.codex; then
        if [ ! -L /home/codex/.codex ]; then
            rm -rf /home/codex/.codex 2>/dev/null || true
            ln -s /config/codex /home/codex/.codex
        fi
    fi

    if [ ! -L /home/codex/.bash_history ]; then
        rm -f /home/codex/.bash_history 2>/dev/null || true
        touch /config/history/bash_history 2>/dev/null || true
        ln -s /config/history/bash_history /home/codex/.bash_history
    fi

    if [ ! -L /home/codex/.gitconfig ] || [ "$(readlink /home/codex/.gitconfig 2>/dev/null || true)" != "/config/git/gitconfig" ]; then
        rm -f /home/codex/.gitconfig 2>/dev/null || true
        ln -s /config/git/gitconfig /home/codex/.gitconfig
    fi

    mkdir -p /home/codex/.config/git 2>/dev/null || true
    if [ ! -L /home/codex/.config/git/config ] || [ "$(readlink /home/codex/.config/git/config 2>/dev/null || true)" != "/config/git/gitconfig" ]; then
        rm -f /home/codex/.config/git/config 2>/dev/null || true
        ln -s /config/git/gitconfig /home/codex/.config/git/config
    fi

    # Set up OpenAI API key if provided
    if [ -n "${OPENAI_API_KEY:-}" ]; then
        export OPENAI_API_KEY="$OPENAI_API_KEY"
        echo -e "${BLUE}OpenAI API key configured${NC}"
    elif [ -f /config/openai_key ]; then
        export OPENAI_API_KEY
        OPENAI_API_KEY="$(cat /config/openai_key)"
        echo -e "${BLUE}OpenAI API key loaded from config${NC}"
    fi

    # Set up git config (empty values are allowed to clear prior config)
    git config --global user.name "$CODEX_GIT_NAME" || true
    git config --global user.email "$CODEX_GIT_EMAIL" || true

    if is_root; then
        if [ -n "$USER_UID" ] && [ -n "$USER_GID" ]; then
            chown -R "$USER_UID:$USER_GID" /config 2>/dev/null || true
        else
            chown -R codex:codex /config 2>/dev/null || true
        fi
    fi
}

setup_ssh_persistence() {
    if [ "$CODEX_SSH_PERSIST" != "true" ]; then
        return
    fi

    mkdir -p /config/ssh 2>/dev/null || true
    chmod 700 /config/ssh 2>/dev/null || true

    if is_mountpoint /home/codex/.ssh; then
        echo -e "${YELLOW}SSH persistence requested but /home/codex/.ssh is a mount. Skipping symlink.${NC}"
    else
        if [ ! -L /home/codex/.ssh ]; then
            rm -rf /home/codex/.ssh 2>/dev/null || true
            ln -s /config/ssh /home/codex/.ssh
        fi
    fi

    if is_root; then
        if [ -n "$USER_UID" ] && [ -n "$USER_GID" ]; then
            chown -R "$USER_UID:$USER_GID" /config/ssh 2>/dev/null || true
        else
            chown -R codex:codex /config/ssh 2>/dev/null || true
        fi
    fi

    if [ -z "$CODEX_SSH_SEED_HOSTS" ]; then
        return
    fi

    if ! command -v ssh-keyscan >/dev/null 2>&1; then
        echo -e "${YELLOW}ssh-keyscan not available; skipping known_hosts seeding.${NC}"
        return
    fi

    local known_hosts="/config/ssh/known_hosts"
    touch "$known_hosts" 2>/dev/null || true
    chmod 600 "$known_hosts" 2>/dev/null || true

    local host
    IFS=',' read -r -a hosts <<< "$CODEX_SSH_SEED_HOSTS"
    for host in "${hosts[@]}"; do
        host="$(echo "$host" | xargs)"
        if [ -z "$host" ]; then
            continue
        fi
        if command -v ssh-keygen >/dev/null 2>&1; then
            if ssh-keygen -F "$host" -f "$known_hosts" >/dev/null 2>&1; then
                continue
            fi
        else
            if grep -q "$host" "$known_hosts" 2>/dev/null; then
                continue
            fi
        fi
        ssh-keyscan -H "$host" >> "$known_hosts" 2>/dev/null || true
    done
}

# Function to display welcome message
show_welcome() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Codex Container - Isolated Development Environment  ${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Container:${NC} ${YELLOW}$(hostname)${NC}"
    echo -e "${BLUE}Workspace:${NC} ${YELLOW}/workspace${NC}"
    echo -e "${BLUE}Config:${NC}    ${YELLOW}/config${NC}"
    if [ -n "${CODEX_HOST_PWD:-}" ]; then
        echo -e "${BLUE}Host CWD:${NC}  ${YELLOW}${CODEX_HOST_PWD}${NC}"
    fi
    if [ -n "${CODEX_HOST_WORKSPACE:-}" ]; then
        echo -e "${BLUE}Host WS:${NC}   ${YELLOW}${CODEX_HOST_WORKSPACE}${NC}"
    fi
    if [ -n "${CODEX_HOST_RELATIVE:-}" ]; then
        echo -e "${BLUE}Host Rel:${NC}  ${YELLOW}${CODEX_HOST_RELATIVE}${NC}"
    fi
    echo -e "${BLUE}Node:${NC}      ${YELLOW}$(node --version)${NC}"
    echo -e "${BLUE}NPM:${NC}       ${YELLOW}$(npm --version)${NC}"

    if command -v codex >/dev/null 2>&1; then
        echo -e "${BLUE}Codex:${NC}     ${GREEN}Installed${NC}"
    else
        echo -e "${BLUE}Codex:${NC}     ${YELLOW}Not installed (package may require manual setup)${NC}"
    fi

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

main() {
    setup_user
    init_config
    setup_ssh_persistence

    # Respect Docker --workdir; only fall back if we start in /
    if [ "${PWD:-/}" = "/" ] && [ -d /workspace ]; then
        cd /workspace
    fi

    # Show welcome message for interactive shell sessions
    if [ -t 1 ] && [ "$#" -eq 1 ] && [ "$1" = "bash" ]; then
        show_welcome
    fi

    if is_root; then
        cmd="$(printf '%q ' "$@")"
        cmd="${cmd% }"
        exec su -s /bin/bash codex -c "$cmd"
    fi

    exec "$@"
}

main "$@"

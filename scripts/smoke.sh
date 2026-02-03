#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
codex="$root_dir/codex-container"

workspace1="$(mktemp -d /tmp/codex-ws1.XXXXXX)"
workspace2="$(mktemp -d /tmp/codex-ws2.XXXXXX)"
container1="cc-smoke-1"
container2="cc-smoke-2"
container3="cc-smoke-docker"

strip_ansi() {
    sed -E 's/\x1B\[[0-9;]*[mK]//g'
}

cleanup() {
    if [ -n "$container1" ]; then
        "$codex" --name "$container1" rm >/dev/null 2>&1 || true
    fi
    if [ -n "$container2" ]; then
        "$codex" --name "$container2" rm >/dev/null 2>&1 || true
    fi
    if [ -n "$container3" ]; then
        "$codex" --name "$container3" rm >/dev/null 2>&1 || true
    fi
    rm -rf "$workspace1" "$workspace2"
}
trap cleanup EXIT

echo "Building image..."
"$codex" --build >/dev/null

echo "Starting runtime container (workspace1)..."
debug_output="$("$codex" --debug -w "$workspace1" --name "$container1" start 2>&1)"
workspace_line="$(printf '%s\n' "$debug_output" | strip_ansi | awk -F'Workspace:' '/Workspace:/ {print $2; exit}' | sed 's/^ *//')"
if [ "$workspace_line" != "$workspace1" ]; then
    echo "Workspace debug mismatch: expected '$workspace1' got '$workspace_line'" >&2
    exit 1
fi

echo "Starting runtime container (workspace2, allow-sudo)..."
"$codex" -w "$workspace2" --name "$container2" --allow-sudo start >/dev/null

if [ "$container1" = "$container2" ]; then
    echo "Container name collision detected" >&2
    exit 1
fi

running1="$(docker inspect -f '{{.State.Running}}' "$container1" 2>/dev/null || true)"
running2="$(docker inspect -f '{{.State.Running}}' "$container2" 2>/dev/null || true)"
if [ "$running1" != "true" ] || [ "$running2" != "true" ]; then
    echo "Expected both containers to be running" >&2
    exit 1
fi

echo "Exec whoami..."
"$codex" -w "$workspace1" --name "$container1" exec -- whoami >/dev/null
"$codex" -w "$workspace2" --name "$container2" exec -- whoami >/dev/null

echo "Persistence check (workspace1)..."
"$codex" -w "$workspace1" --name "$container1" exec -- sh -lc 'echo hi > /tmp/persist-test-a && cat /tmp/persist-test-a' >/dev/null
"$codex" -w "$workspace1" --name "$container1" exec -- cat /tmp/persist-test-a >/dev/null

echo "Persistence check (workspace2)..."
"$codex" -w "$workspace2" --name "$container2" exec -- sh -lc 'echo hi > /tmp/persist-test-b && cat /tmp/persist-test-b' >/dev/null
"$codex" -w "$workspace2" --name "$container2" exec -- cat /tmp/persist-test-b >/dev/null

echo "pipx check (informational)..."
if "$codex" -w "$workspace1" --name "$container1" pipx list >/dev/null 2>&1; then
    echo "pipx available"
else
    echo "pipx not available or no packages installed"
fi

echo "Git config propagation check..."
if ! "$codex" -w "$workspace1" --name "$container1" exec -- sh -lc 'test -f /config/git/gitconfig'; then
    echo "Missing /config/git/gitconfig in container" >&2
    exit 1
fi

config_name="$($codex -w "$workspace1" --name "$container1" exec -- sh -lc 'git config --file /config/git/gitconfig --get user.name || true' | tr -d '\r')"
config_email="$($codex -w "$workspace1" --name "$container1" exec -- sh -lc 'git config --file /config/git/gitconfig --get user.email || true' | tr -d '\r')"
if [ -z "$config_name" ] || [ -z "$config_email" ]; then
    echo "Expected /config/git/gitconfig to include user.name and user.email" >&2
    exit 1
fi

if ! "$codex" -w "$workspace1" --name "$container1" exec -- sh -lc 'test -e ~/.gitconfig'; then
    echo "Missing $HOME/.gitconfig in container" >&2
    exit 1
fi

gitconfig_target="$($codex -w "$workspace1" --name "$container1" exec -- sh -lc 'if [ -L ~/.gitconfig ]; then if readlink -f ~/.gitconfig >/dev/null 2>&1; then readlink -f ~/.gitconfig; else readlink ~/.gitconfig; fi; fi' | tr -d '\r')"
if [ -n "$gitconfig_target" ] && [ "$gitconfig_target" != "/config/git/gitconfig" ]; then
    echo "$HOME/.gitconfig symlink target mismatch: $gitconfig_target" >&2
    exit 1
fi

container_name="$($codex -w "$workspace1" --name "$container1" exec -- git config --global user.name | tr -d '\r')"
container_email="$($codex -w "$workspace1" --name "$container1" exec -- git config --global user.email | tr -d '\r')"
if [ "$container_name" != "$config_name" ]; then
    echo "Git user.name mismatch: expected '$config_name' got '$container_name'" >&2
    exit 1
fi
if [ "$container_email" != "$config_email" ]; then
    echo "Git user.email mismatch: expected '$config_email' got '$container_email'" >&2
    exit 1
fi

origin_name="$($codex -w "$workspace1" --name "$container1" exec -- git config --global --show-origin user.name | tr -d '\r')"
origin_email="$($codex -w "$workspace1" --name "$container1" exec -- git config --global --show-origin user.email | tr -d '\r')"
case "$origin_name" in
    *"file:/home/codex/.gitconfig"*|*"file:/config/git/gitconfig"*) ;;
    *) echo "Git user.name origin unexpected: $origin_name" >&2; exit 1 ;;
esac
case "$origin_email" in
    *"file:/home/codex/.gitconfig"*|*"file:/config/git/gitconfig"*) ;;
    *) echo "Git user.email origin unexpected: $origin_email" >&2; exit 1 ;;
esac

host_name="$(git config --global user.name 2>/dev/null || true)"
host_email="$(git config --global user.email 2>/dev/null || true)"
if [ -n "$host_name" ] && [ "$container_name" != "$host_name" ]; then
    echo "Git user.name mismatch with host: expected '$host_name' got '$container_name'" >&2
    exit 1
fi
if [ -n "$host_email" ] && [ "$container_email" != "$host_email" ]; then
    echo "Git user.email mismatch with host: expected '$host_email' got '$container_email'" >&2
    exit 1
fi

echo "Concurrency check..."
if [ "$container1" = "$container2" ]; then
    echo "Container name collision detected" >&2
    exit 1
fi

echo "Sudo behavior check..."
if "$codex" -w "$workspace1" --name "$container1" exec -- sudo -n true >/dev/null 2>&1; then
    echo "Expected sudo to be blocked in default container" >&2
    exit 1
fi
if ! "$codex" -w "$workspace2" --name "$container2" exec -- sudo -n true >/dev/null 2>&1; then
    echo "Expected sudo to be enabled in allow-sudo container" >&2
    exit 1
fi
"$codex" -w "$workspace2" --name "$container2" exec -- sudo apk add --no-cache jq >/dev/null

if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "${SSH_AUTH_SOCK:-}" ]; then
    echo "SSH agent forwarding check..."
    # shellcheck disable=SC2016 # Deferred expansion inside container shell.
    "$codex" -w "$workspace1" --name "$container1" exec -- sh -lc 'test -S "$SSH_AUTH_SOCK"' >/dev/null
fi

echo "Runtime docker socket check..."
"$codex" -w "$workspace1" --name "$container3" --allow-docker start >/dev/null
"$codex" -w "$workspace1" --name "$container3" exec -- sh -lc 'docker version >/dev/null && docker ps >/dev/null'

echo "Smoke tests passed"

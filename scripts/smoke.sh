#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
codex="$root_dir/codex-container"

workspace1="$(mktemp -d /tmp/codex-ws1.XXXXXX)"
workspace2="$(mktemp -d /tmp/codex-ws2.XXXXXX)"
container1="cc-smoke-1"
container2="cc-smoke-2"

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

echo "pipx check..."
"$codex" -w "$workspace1" --name "$container1" pipx list >/dev/null

host_name="$(git config --global user.name 2>/dev/null || true)"
host_email="$(git config --global user.email 2>/dev/null || true)"
if [ -n "$host_name" ]; then
    container_name="$($codex -w "$workspace1" --name "$container1" exec -- git config --global user.name | tr -d '\r')"
    if [ "$container_name" != "$host_name" ]; then
        echo "Git user.name mismatch: expected '$host_name' got '$container_name'" >&2
        exit 1
    fi
fi
if [ -n "$host_email" ]; then
    container_email="$($codex -w "$workspace1" --name "$container1" exec -- git config --global user.email | tr -d '\r')"
    if [ "$container_email" != "$host_email" ]; then
        echo "Git user.email mismatch: expected '$host_email' got '$container_email'" >&2
        exit 1
    fi
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
    "$codex" -w "$workspace1" --name "$container1" exec -- sh -lc 'test -S "$SSH_AUTH_SOCK"' >/dev/null
fi

echo "Smoke tests passed"

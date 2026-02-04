#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
codex="$root_dir/codex-container"

workspace1="$(mktemp -d /tmp/codex-ws1.XXXXXX)"
workspace2="$(mktemp -d /tmp/codex-ws2.XXXXXX)"
workspace3="$(mktemp -d /tmp/codex-ws3.XXXXXX)"
config_dir="$(mktemp -d /tmp/codex-config-smoke.XXXXXX)"
chmod 777 "$config_dir"
smoke_id="$(date +%s)-$$"
container1="cc-smoke-1-$smoke_id"
container2="cc-smoke-2-$smoke_id"
container3="cc-smoke-docker-$smoke_id"
container4=""
smoke_git_name="Codex Container Smoke"
smoke_git_email="smoke@example.invalid"
smoke_debug_args=()
smoke_label="io.codex-container.smoke_id=$smoke_id"

if [ "${SMOKE_DEBUG:-}" = "1" ]; then
    smoke_debug_args=(--debug)
fi

export CODEX_GIT_NAME="$smoke_git_name"
export CODEX_GIT_EMAIL="$smoke_git_email"
export CODEX_CONFIG="$config_dir"

wait_for_container_running() {
    local name="$1"
    local timeout="${2:-10}"
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if [ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || true)" = "true" ]; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

hash_path() {
    local input="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$input" | sha256sum | awk '{print $1}'
        return
    fi
    if command -v shasum >/dev/null 2>&1; then
        printf '%s' "$input" | shasum -a 256 | awk '{print $1}'
        return
    fi
    if command -v md5sum >/dev/null 2>&1; then
        printf '%s' "$input" | md5sum | awk '{print $1}'
        return
    fi
    if command -v md5 >/dev/null 2>&1; then
        printf '%s' "$input" | md5 -q
        return
    fi
    printf '%s' "$input" | cksum | awk '{print $1}'
}

resolve_workspace_container() {
    local workspace="$1"
    local resolved
    resolved="$(cd "$workspace" && pwd -P)"
    local hash
    hash="$(hash_path "$resolved")"
    docker ps -a \
        --filter "label=io.codex-container.managed=true" \
        --filter "label=io.codex-container.workspace_hash=$hash" \
        --format '{{.Names}}' | head -n 1
}

start_runtime_container() {
    local name="$1"
    local workspace="$2"
    local allow_sudo="${3:-false}"
    local allow_docker="${4:-false}"
    local -a args=()
    local output=""

    args+=( "$codex" "${smoke_debug_args[@]}" -w "$workspace" --name "$name" --label "$smoke_label" )
    if [ "$allow_sudo" = "true" ]; then
        args+=( --allow-sudo )
    fi
    if [ "$allow_docker" = "true" ]; then
        args+=( --allow-docker )
    fi

    if ! output="$("${args[@]}" start 2>&1)"; then
        echo "Failed to start container $name" >&2
        printf '%s\n' "$output" >&2
        dump_smoke_diagnostics
        exit 1
    fi

    local workspace_label=""
    workspace_label="$(docker inspect -f '{{ index .Config.Labels "com.codex.workspace" }}' "$name" 2>/dev/null || true)"
    if [ -z "$workspace_label" ] || [ "$workspace_label" != "$workspace" ]; then
        echo "Workspace label mismatch: expected '$workspace' got '$workspace_label'" >&2
        printf '%s\n' "$output" >&2
        dump_smoke_diagnostics
        exit 1
    fi
}

dump_container_state() {
    local name="$1"
    if ! docker container inspect "$name" >/dev/null 2>&1; then
        echo "Container $name not found"
        return
    fi
    echo "Container $name state:"
    docker inspect --format='  Status={{.State.Status}} Running={{.State.Running}} ExitCode={{.State.ExitCode}} Error={{.State.Error}} OOMKilled={{.State.OOMKilled}}' "$name" || true
    docker inspect --format='  StartedAt={{.State.StartedAt}} FinishedAt={{.State.FinishedAt}}' "$name" || true
    docker inspect --format='  Entrypoint={{.Config.Entrypoint}}' "$name" || true
    docker inspect --format='  Cmd={{.Config.Cmd}}' "$name" || true
}

dump_smoke_diagnostics() {
    echo "Smoke diagnostics:"
    docker ps -a || true
    dump_container_state "$container1"
    dump_container_state "$container2"
    dump_container_state "$container3"
    if docker container inspect "$container1" >/dev/null 2>&1; then
        echo "Logs for $container1:"
        docker logs "$container1" || true
    fi
    if docker container inspect "$container2" >/dev/null 2>&1; then
        echo "Logs for $container2:"
        docker logs "$container2" || true
    fi
    if docker container inspect "$container3" >/dev/null 2>&1; then
        echo "Logs for $container3:"
        docker logs "$container3" || true
    fi
}

cleanup() {
    if [ -n "$smoke_label" ]; then
        "$codex" --label "$smoke_label" clean --all --yes >/dev/null 2>&1 || true
    fi
    if [ -n "$container1" ]; then
        "$codex" --name "$container1" rm >/dev/null 2>&1 || true
    fi
    if [ -n "$container2" ]; then
        "$codex" --name "$container2" rm >/dev/null 2>&1 || true
    fi
    if [ -n "$container3" ]; then
        "$codex" --name "$container3" rm >/dev/null 2>&1 || true
    fi
    if [ -n "$container4" ]; then
        "$codex" --name "$container4" rm >/dev/null 2>&1 || true
    fi
    rm -rf "$workspace1" "$workspace2" "$workspace3" "$config_dir"
}
trap cleanup EXIT

echo "Building image..."
"$codex" --build >/dev/null

echo "Starting runtime container (workspace1)..."
start_runtime_container "$container1" "$workspace1"

echo "Starting runtime container (workspace2, allow-sudo)..."
start_runtime_container "$container2" "$workspace2" "true"

if [ "$container1" = "$container2" ]; then
    echo "Container name collision detected" >&2
    exit 1
fi

if ! wait_for_container_running "$container1" 10 || ! wait_for_container_running "$container2" 10; then
    echo "Expected both containers to be running" >&2
    dump_smoke_diagnostics
    exit 1
fi

echo "Name collision check (expected failure)..."
set +e
collision_output="$("$codex" -w "$workspace2" --name "$container1" --label "$smoke_label" start 2>&1)"
collision_status=$?
set -e
if [ "$collision_status" -eq 0 ]; then
    echo "Expected name collision to fail" >&2
    printf '%s\n' "$collision_output" >&2
    dump_smoke_diagnostics
    exit 1
fi
if ! printf '%s\n' "$collision_output" | grep -F -q "Container name collision"; then
    echo "Expected name collision error message" >&2
    printf '%s\n' "$collision_output" >&2
    dump_smoke_diagnostics
    exit 1
fi
echo "Name collision check (expected failure): ok"

echo "Lifecycle regression check..."
pushd "$workspace3" >/dev/null
if ! "$codex" "${smoke_debug_args[@]}" --label "$smoke_label" start >/dev/null 2>&1; then
    echo "Failed to start lifecycle container in $workspace3" >&2
    dump_smoke_diagnostics
    exit 1
fi
popd >/dev/null

container4="$(resolve_workspace_container "$workspace3")"
if [ -z "$container4" ]; then
    echo "Failed to resolve lifecycle container for workspace3" >&2
    dump_smoke_diagnostics
    exit 1
fi

if ! wait_for_container_running "$container4" 10; then
    echo "Expected lifecycle container to be running" >&2
    dump_smoke_diagnostics
    exit 1
fi

"$codex" -w "$workspace1" --name "$container1" --label "$smoke_label" start >/dev/null 2>&1 || true

pushd "$workspace3" >/dev/null
if ! "$codex" status >/dev/null 2>&1; then
    echo "Lifecycle status failed for workspace3" >&2
    dump_smoke_diagnostics
    exit 1
fi
if ! "$codex" stop >/dev/null 2>&1; then
    echo "Lifecycle stop failed for workspace3" >&2
    dump_smoke_diagnostics
    exit 1
fi
if ! "$codex" rm >/dev/null 2>&1; then
    echo "Lifecycle rm failed for workspace3" >&2
    dump_smoke_diagnostics
    exit 1
fi
popd >/dev/null

if docker container inspect "$container4" >/dev/null 2>&1; then
    echo "Expected lifecycle container to be removed: $container4" >&2
    dump_smoke_diagnostics
    exit 1
fi

echo "Exec whoami..."
"$codex" -w "$workspace1" --name "$container1" exec -- whoami >/dev/null
"$codex" -w "$workspace2" --name "$container2" --allow-sudo exec -- whoami >/dev/null

echo "Persistence check (workspace1)..."
"$codex" -w "$workspace1" --name "$container1" exec -- sh -lc 'echo hi > /tmp/persist-test-a && cat /tmp/persist-test-a' >/dev/null
"$codex" -w "$workspace1" --name "$container1" exec -- cat /tmp/persist-test-a >/dev/null

echo "Persistence check (workspace2)..."
"$codex" -w "$workspace2" --name "$container2" --allow-sudo exec -- sh -lc 'echo hi > /tmp/persist-test-b && cat /tmp/persist-test-b' >/dev/null
"$codex" -w "$workspace2" --name "$container2" --allow-sudo exec -- cat /tmp/persist-test-b >/dev/null

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
expected_name="${CODEX_GIT_NAME:-$host_name}"
expected_email="${CODEX_GIT_EMAIL:-$host_email}"
if [ -n "$expected_name" ] && [ "$container_name" != "$expected_name" ]; then
    echo "Git user.name mismatch: expected '$expected_name' got '$container_name'" >&2
    exit 1
fi
if [ -n "$expected_email" ] && [ "$container_email" != "$expected_email" ]; then
    echo "Git user.email mismatch: expected '$expected_email' got '$container_email'" >&2
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
if ! "$codex" -w "$workspace2" --name "$container2" --allow-sudo exec -- sudo -n true >/dev/null 2>&1; then
    echo "Expected sudo to be enabled in allow-sudo container" >&2
    exit 1
fi
"$codex" -w "$workspace2" --name "$container2" --allow-sudo exec -- sudo apk add --no-cache jq >/dev/null

if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "${SSH_AUTH_SOCK:-}" ]; then
    echo "SSH agent forwarding check..."
    # shellcheck disable=SC2016 # Deferred expansion inside container shell.
    if ! "$codex" -w "$workspace1" --name "$container1" exec -- sh -lc 'test -S "$SSH_AUTH_SOCK"' >/dev/null; then
        echo "Warning: SSH agent socket not available inside container; skipping agent forwarding check"
    fi
fi

echo "Runtime docker socket check..."
start_runtime_container "$container3" "$workspace1" "false" "true"
"$codex" -w "$workspace1" --name "$container3" --allow-docker exec -- sh -lc 'docker version >/dev/null && docker ps >/dev/null'

echo "Smoke cleanup (label)..."
"$codex" --label "$smoke_label" clean --all --yes >/dev/null 2>&1 || true
remaining="$(docker ps -a --filter "label=$smoke_label" --format '{{.ID}}')"
if [ -n "$remaining" ]; then
    echo "Expected no containers with smoke label after cleanup: $smoke_label" >&2
    docker ps -a --filter "label=$smoke_label" --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}' >&2 || true
    exit 1
fi

echo "Smoke tests passed"

#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
codex="$root_dir/codex-container"
export CODEX_CONFIG="/tmp/codex-config-nodocker"

if ! "$codex" --help >/dev/null; then
    echo "--help failed" >&2
    exit 1
fi

help_output="$($codex --help)"
printf '%s\n' "$help_output" | grep -F -q "prune-images"
printf '%s\n' "$help_output" | grep -F -q -- "--allow-docker"
printf '%s\n' "$help_output" | grep -F -q -- "--dry-run"

if ! "$codex" --version >/dev/null; then
    echo "--version failed" >&2
    exit 1
fi

if [ ! -s "$root_dir/completions/codex-container.bash" ]; then
    echo "Missing or empty bash completion" >&2
    exit 1
fi
if [ ! -s "$root_dir/completions/_codex-container" ]; then
    echo "Missing or empty zsh completion" >&2
    exit 1
fi

for target in install-user uninstall-user install uninstall install-symlink prune-images ci-local; do
    if ! grep -q "^${target}:" "$root_dir/Makefile"; then
        echo "Missing Makefile target: $target" >&2
        exit 1
    fi
done

workspace="$(mktemp -d /tmp/codex-nodocker.XXXXXX)"
trap 'rm -rf "$workspace"' EXIT

dry_output="$($codex --dry-run -w "$workspace" start)"
printf '%s\n' "$dry_output" | grep -q "DRY RUN: docker run"
printf '%s\n' "$dry_output" | grep -q "$workspace:/workspace"

dry_exec="$($codex --dry-run --name nodocker exec -- ls)"
printf '%s\n' "$dry_exec" | grep -q "DRY RUN: docker exec"

echo "No-docker tests passed"

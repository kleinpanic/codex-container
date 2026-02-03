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
if ! grep -q "^install-user-copy:" "$root_dir/Makefile"; then
    echo "Missing Makefile target: install-user-copy" >&2
    exit 1
fi

workspace="$(mktemp -d /tmp/codex-nodocker.XXXXXX)"
temp_home="$(mktemp -d /tmp/codex-home.XXXXXX)"
temp_bin="$temp_home/.local/bin"
repo_version="$(cat "$root_dir/VERSION")"
trap 'rm -rf "$workspace" "$temp_home"' EXIT

dry_output="$($codex --dry-run -w "$workspace" start)"
printf '%s\n' "$dry_output" | grep -q "DRY RUN: docker run"
printf '%s\n' "$dry_output" | grep -q "$workspace:/workspace"

dry_exec="$($codex --dry-run --name nodocker exec -- ls)"
printf '%s\n' "$dry_exec" | grep -q "DRY RUN: docker exec"

HOME="$temp_home" PATH="$temp_bin:$PATH" make -s install-user
version_output="$(HOME="$temp_home" PATH="$temp_bin:$PATH" codex-container --version)"
printf '%s\n' "$version_output" | grep -F -q "$repo_version"
HOME="$temp_home" PATH="$temp_bin:$PATH" make -s uninstall-user
if HOME="$temp_home" PATH="$temp_bin" command -v codex-container >/dev/null 2>&1; then
    echo "install-user uninstall failed" >&2
    exit 1
fi

HOME="$temp_home" PATH="$temp_bin:$PATH" make -s install-user-copy
version_output="$(HOME="$temp_home" PATH="$temp_bin:$PATH" codex-container --version)"
printf '%s\n' "$version_output" | grep -F -q "$repo_version"
HOME="$temp_home" PATH="$temp_bin:$PATH" make -s uninstall-user

echo "No-docker tests passed"

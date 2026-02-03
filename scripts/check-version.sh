#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
version_file="$root_dir/VERSION"

die() {
    echo "Error: $*" >&2
    exit 1
}

if [ ! -f "$version_file" ]; then
    die "VERSION file not found"
fi

version="$(cat "$version_file")"
if [ -z "$version" ]; then
    die "VERSION file is empty"
fi

if ! grep -F -q "ARG CODEX_VERSION" "$root_dir/Dockerfile"; then
    die "Dockerfile missing ARG CODEX_VERSION"
fi
if ! grep -F -q "LABEL version=\"\${CODEX_VERSION}\"" "$root_dir/Dockerfile"; then
    die "Dockerfile version label must reference CODEX_VERSION"
fi

if [ -f "$root_dir/Dockerfile.agent" ]; then
    if ! grep -F -q "ARG CODEX_VERSION" "$root_dir/Dockerfile.agent"; then
        die "Dockerfile.agent missing ARG CODEX_VERSION"
    fi
    if ! grep -F -q "LABEL version=\"\${CODEX_VERSION}\"" "$root_dir/Dockerfile.agent"; then
        die "Dockerfile.agent version label must reference CODEX_VERSION"
    fi
fi

if ! grep -F -q "image: codex-container:\${CODEX_VERSION}" "$root_dir/docker-compose.yml"; then
    die "docker-compose.yml must reference CODEX_VERSION for image"
fi

if ! grep -F -q "VERSION := \$(shell cat VERSION" "$root_dir/Makefile"; then
    die "Makefile must read VERSION from VERSION file"
fi

if ! grep -F -q "DEFAULT_VERSION=\"$version\"" "$root_dir/codex-container"; then
    die "codex-container DEFAULT_VERSION must match VERSION file"
fi
if ! grep -F -q 'SCRIPT_DIR="$(resolve_script_dir)"' "$root_dir/codex-container"; then
    die "codex-container must resolve SCRIPT_DIR"
fi

echo "Version check passed: $version"

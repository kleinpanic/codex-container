#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
codex="$root_dir/codex-container"

echo "Running agent smoke..."
"$codex" --agent-workspace "$root_dir" agent --agent-docker -- ./scripts/smoke.sh

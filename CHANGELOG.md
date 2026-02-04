# Changelog

## 1.3.11 - 2026-02-04

Summary:
- Added `ps` to list managed containers for the current workspace (with `--all` support).
- Improved multi-container guidance when more than one managed container matches a workspace.
- Quieted smoke output by default and clarified the expected name-collision check.
- Added a safety guard for `clean --all` when invoked from inside managed containers, with `--force` to override or `--label` to scope.

## 1.3.6 - 2026-02-04

Summary:
- Fixed workspace container targeting by resolving containers via labels and container IDs.
- Added `doctor` for SSH agent diagnostics and improved forwarding warnings.
- Added optional SSH persistence and known_hosts seeding.

## 1.3.5 - 2026-02-03

Summary:
- Hardened smoke tests to capture Docker errors and avoid false failures when containers already exist.
- Ensured config directories are writable for container startup when host UID/GID differ (fixes CI container exits).

## 1.3.3 - 2026-02-03

Summary:
- Cleaned up ShellCheck findings to unblock CI without changing behavior.

## 1.3.0 - 2026-02-03

Summary:
- Added user-local and system install/uninstall Make targets, plus optional symlink install.
- Added runtime Docker socket opt-in (`--allow-docker`) and project-scoped image pruning (`prune-images`).
- Added `--dry-run` for no-Docker validation and CI tiering with a no-Docker test script.
- Added bash/zsh completion scripts and documentation updates.
- Hardened git identity propagation with persistent global config symlinks.

## 1.2.0 - 2026-02-03

Summary:
- Added agent container mode with optional host Docker socket passthrough for running Docker-based tests inside a container.
- Introduced companion agent image (Dockerfile.agent) with docker CLI and basic tooling.
- Added agent smoke helper script and agent-focused CLI flags.

## 1.1.0 - 2026-02-03

Summary:
- Introduced per-workspace persistent runtime containers with new `start/stop/rm/status/shell/exec` commands.
- Added explicit sudo opt-in (`--allow-sudo`) with no-new-privileges enabled by default.
- Added pipx/pip cache persistence and MCP wrappers.
- Added SSH agent forwarding and host git identity propagation.
- Added version single-source-of-truth via `VERSION` and a `version-check` script.

Previous behavior (1.0.0):
- Default invocation ran `codex` in a one-shot container.
- `--shell` launched an ephemeral container.
- `--name` defaulted to a single hard-coded container name (`codex-container-runtime`).
- Persistence relied on a host-mounted `/config` and a named npm volume; container filesystem was discarded via `--rm`.
- No `no-new-privileges` policy was applied by default; sudo was installed and intended to work.

Details:
- The runtime container name is now workspace-scoped (deterministic hash) unless `--name` is provided.
- Management commands (`status`, `logs`, `exec`) accept `--name` and fall back to the last used container.
- `CODEX_WORKSPACE=~/...` now expands reliably; script directory resolution works when invoked via symlink.
- Added `--ephemeral` to explicitly request legacy `docker run --rm` behavior.
- Git identity is pulled from host `git config --global` and stored in `/config/git/gitconfig` in the container.
- Default base image now includes git/ssh, curl, jq, python/pip/pipx, and build tools.

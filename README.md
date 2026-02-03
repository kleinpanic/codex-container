# Codex Container

Run the OpenAI Codex CLI in a clean, repeatable Docker environment with workspace mounting, automatic `.env` injection, and persistent Codex config/state.

This repo gives you a single command (`codex-container`) that behaves like a persistent Codex runtime you can use across projects without polluting your host machine.

---

## Docs

- `USAGE.md` for practical setup and workflows.

## Features

- Codex-first UX: `codex-container --search` routes leading flags to `codex`.
- Persistent per-workspace runtime container: `start/stop/rm/status/shell/exec` manage a workspace-scoped container and avoid name collisions.
- Workspace mounting + correct working directory: Mount any folder to `/workspace` and mirror host subdirectories when possible.
- Automatic `.env` injection: If your project has a `.env`, it is loaded into the container environment.
- Persistent configuration: Codex config/state persists under your host config dir and survives rebuilds.
- pip/pipx persistence: pipx installs live under `/config/pipx` and remain available across sessions.
- SSH agent forwarding: If `SSH_AUTH_SOCK` is set, it is forwarded into the container.
- Git identity propagation: Host `git config --global user.name/email` is applied to container global git config.
- Agent container mode: Run an isolated tooling container with optional host Docker socket passthrough.
- Runtime Docker opt-in: `--allow-docker` exposes the host Docker socket only when requested.
- Shell completions for bash/zsh.
- `prune-images` for project-scoped image cleanup and `--dry-run` for safe inspection.

---

## Quick Start

### 1) Build the image

```bash
./codex-container --build
```

### 2) Start a runtime container for your current workspace

```bash
./codex-container start
```

### 3) Run Codex in that workspace

```bash
./codex-container --search
```

---

## Installation

### User-local install (recommended)

```bash
make install-user
command -v codex-container
codex-container --version
```

If you prefer a standalone copy instead of a symlink:

```bash
make install-user-copy
```

Uninstall:

```bash
make uninstall-user
```

If `~/.local/bin` is not on PATH, add it in your shell profile.

### System-wide install (optional)

```bash
make install
command -v codex-container
```

Uninstall:

```bash
make uninstall
```

If you want a symlink instead of a copy:

```bash
make install-symlink
```

Confirm which binary is used:

```bash
command -v codex-container
```

---

## Releasing

- Bump `VERSION` (x.y.z).
- Run `make smoke`.
- Tag the release: `git tag vX.Y.Z`.
- Push the tag: `git push origin vX.Y.Z`.
- CI publishes the GitHub Release.

---

## Usage

### Runtime container lifecycle

```bash
# Create or start the per-workspace runtime container
./codex-container start

# Stop the runtime container
./codex-container stop

# Remove the runtime container (clean reset)
./codex-container rm

# Show status for the current workspace container
./codex-container status

# Prune old codex-container images (keeps current VERSION tag)
./codex-container prune-images
```

### Codex runs

```bash
# Default behavior (runs codex)
./codex-container

# Run codex explicitly
./codex-container codex --search

# Leading flags default to codex
./codex-container --search
./codex-container --full-auto --search

# Use a custom env file
./codex-container --env-file /path/to/.env --search
```

### Shell / tools

```bash
# Drop into a shell inside the runtime container
./codex-container shell

# Run an arbitrary command inside the runtime container
./codex-container exec -- npm list
./codex-container exec -- node script.js
./codex-container npx cowsay hello
```

### MCP management

```bash
./codex-container mcp list
./codex-container mcp add ...
./codex-container mcp remove ...
```

### pipx helpers

```bash
./codex-container pipx list
./codex-container pipx install <pkg>
```

### Container management with explicit names

```bash
./codex-container --name my-runtime status
./codex-container --name my-runtime logs
./codex-container --name my-runtime exec -- bash -lc 'ls -la'
```

### Ephemeral runs (legacy)

```bash
./codex-container --ephemeral --search
./codex-container --ephemeral shell
```

### Agent container mode (Docker socket passthrough)

Use the agent container when you need a containerized environment that can still run Docker commands against the host daemon.

Warning: `--agent-docker` grants the agent container control of the host Docker daemon.

```bash
# Run a command inside the agent container with Docker access
./codex-container agent --agent-docker -- ./scripts/smoke.sh

# Open a shell in the agent container (defaults to shell if no command)
./codex-container agent --agent-docker

# Specify a different agent image or workspace
./codex-container agent --agent-image my-agent:latest --agent-workspace /path/to/repo -- ./scripts/smoke.sh
```

Notes:
- The agent container mounts the workspace at the same absolute path and also mounts `/tmp` for host path parity.
- If your host Docker socket requires elevated permissions, use `--agent-root` explicitly.
- Use `./scripts/agent-smoke.sh` to run the existing smoke tests from inside the agent container.

---

## Security model

By default, the runtime container starts with `no-new-privileges`, so `sudo` and `apk add` are blocked.

To opt into sudo for a specific runtime container:

```bash
./codex-container --allow-sudo start
```

If a container already exists without sudo, remove it and recreate with `--allow-sudo`.

Runtime Docker socket access is disabled by default. If you enable `--allow-docker`, the runtime container can control the host Docker daemon.

Agent mode is separate from the runtime container. If you enable `--agent-docker`, the agent container can control the host Docker daemon.

---

## `.env` Autoload Behavior

If you do not provide `--env-file`, the wrapper tries to load:

1. `.env` in your current directory (if inside the workspace), otherwise
2. `.env` at the workspace root.

The `.env` file is translated into `docker exec -e` arguments so variables are available to Codex and tools in the runtime container.

---

## Persistence & Where Things Live

By default, config persists on the host under:

- Host: `~/.config/codex-container/config`
- Container: mounted to `/config`

Persistent subpaths:

- `/config/codex` contains Codex state/config. On first run, `codex.config.toml` is copied to `/config/codex/config.toml`.
- `/config/npm` stores npm config/cache (symlinked to `/home/codex/.npm`).
- `/config/history` stores persistent bash history at `/config/history/bash_history`.
- `/config/pipx` stores pipx home and bin directory.
- `/config/pip-cache` stores pip cache.

Global npm installs persist via Docker volume:

- `codex-npm-global` -> `/home/codex/.npm-global`

---

## Optional: Mount Host `~/.codex`

If you want the container to use your host’s Codex auth/config directly:

```bash
./codex-container --host-codex-dir --search
```

This mounts:

- Host: `~/.codex`
- Container: `/home/codex/.codex`

If you don’t use this option, Codex state is persisted in `/config/codex` instead.

---

## SSH Agent Forwarding

If `SSH_AUTH_SOCK` is set on the host, the wrapper forwards it into the container at `/ssh-agent` and sets `SSH_AUTH_SOCK` accordingly. If not set, the wrapper logs a warning but continues.

---

## Git Identity Propagation

On `start`, the wrapper reads host git global config (`user.name`, `user.email`) and applies it inside the container. The container global git config is stored at `/config/git/gitconfig`, so it persists across container recreation. Repo-local git configs are not modified.

If you prefer to supply values explicitly, you can set `CODEX_GIT_NAME` and `CODEX_GIT_EMAIL` on the host.

---

## Runtime Docker Socket (opt-in)

The runtime container can optionally access the host Docker daemon. This is disabled by default.

```bash
./codex-container --allow-docker start
```

Warning: `--allow-docker` grants the runtime container control of the host Docker daemon.

---

## Shell Completions

Completion scripts live under `completions/`.

```bash
# Bash (one-time for current shell)
source completions/codex-container.bash
```

```bash
# Zsh (add to fpath or copy into a site-functions dir)
fpath=(\"$(pwd)/completions\" $fpath)
autoload -Uz compinit && compinit
```

---

## Dry Run

Use `--dry-run` to print the resolved Docker commands without executing them:

```bash
./codex-container --dry-run start
./codex-container --dry-run exec -- ls -la
```

## Environment Variables

These are wrapper controls and passthrough helpers:

### Wrapper controls

- `CODEX_WORKSPACE` — default workspace directory
- `CODEX_CONFIG` — default config directory
- `CODEX_IMAGE` — docker image name/tag override
- `OPENAI_API_KEY` — API key (also supported via `/config/openai_key`)
- `CODEX_GIT_NAME` — sets global git user.name inside container
- `CODEX_GIT_EMAIL` — sets global git user.email inside container

### Host context passthrough (always injected)

- `CODEX_HOST_PWD` — your host working directory
- `CODEX_HOST_WORKSPACE` — resolved host workspace root
- `CODEX_HOST_RELATIVE` — host subdirectory relative to workspace (used to set container workdir)

---

## Codex Configuration (`codex.config.toml`)

This repo includes `codex.config.toml` as a template.

On first run, the container copies it to:

- `/config/codex/config.toml` (persistent)

You can edit the persistent config at:

- `~/.config/codex-container/config/codex/config.toml`

Tip: keep project-specific secrets out of this file and use `.env` instead.

---

## Directory Structure

```
codex-container/
├── Dockerfile
├── Dockerfile.agent
├── VERSION
├── CHANGELOG.md
├── docker-compose.yml
├── codex-container
├── entrypoint.sh
├── codex.config.toml
├── completions/
├── Makefile
├── SETUP_GUIDE.txt
├── scripts/agent-smoke.sh
└── README.md
```

---

## License

MIT (see `LICENSE`).

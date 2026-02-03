# Usage Guide

Codex Container wraps the OpenAI Codex CLI in a repeatable Docker runtime. It solves three common problems:

- Keep Codex and dependencies isolated from your host machine.
- Preserve a workspace-scoped runtime container across sessions.
- Persist Codex config/state and common tooling caches in a predictable location.

## Installation

User-local install (symlink to the repo):

```bash
make install-user
command -v codex-container
```

User-local install (copy a standalone script):

```bash
make install-user-copy
command -v codex-container
```

Uninstall:

```bash
make uninstall-user
```

System-wide install:

```bash
make install
```

Uninstall:

```bash
make uninstall
```

Version reporting works for both symlink and copy installs.

## Config and State

By default, config and state persist on the host under:

- `~/.config/codex-container/config`

Inside the runtime container, that directory is mounted at `/config`.

## Core Workflows

Build the image:

```bash
./codex-container --build
make build
```

Start a runtime container:

```bash
./codex-container start
./codex-container --name my-runtime start
./codex-container -w /path/to/project --name my-runtime start
```

Exec commands in the runtime container:

```bash
./codex-container exec -- whoami
./codex-container --name my-runtime exec -- bash -lc 'ls -la'
```

Sudo opt-in (runtime container only):

```bash
./codex-container --allow-sudo start
```

`--allow-sudo` disables `no-new-privileges` for that runtime container and permits `sudo` inside it. If the container already exists, remove it and recreate with `--allow-sudo`.

Docker opt-in (runtime container only):

```bash
./codex-container --allow-docker start
```

Security warning: `--allow-docker` grants the container control of the host Docker daemon. Only enable it when you need it.

Codex invocation patterns:

```bash
# Default behavior (runs codex)
./codex-container --search

# Explicit subcommand
./codex-container codex --search

# Explicit flag
./codex-container --codex --search
```

Agent mode (Docker socket passthrough):

```bash
# Run a command inside the agent container with Docker access
./codex-container agent --agent-docker -- ./scripts/smoke.sh

# Open a shell in the agent container
./codex-container agent --agent-docker
```

If your host Docker socket requires elevated permissions, add `--agent-root`.

## Git Identity Propagation

Codex Container discovers your git identity from these sources (first match wins):

- `CODEX_GIT_NAME` / `CODEX_GIT_EMAIL`
- `GIT_USER_NAME` / `GIT_USER_EMAIL`
- `git config --global user.name` / `git config --global user.email`

The values are stored in `/config/git/gitconfig` and applied inside the runtime container via the global git config (and a symlinked `~/.gitconfig` when available).

## Shell Completions

Bash:

```bash
source completions/codex-container.bash
```

Zsh:

```bash
fpath=($(pwd)/completions $fpath)
autoload -U compinit && compinit
```

## Troubleshooting

Docker socket permission denied:

- Ensure your user can access `/var/run/docker.sock`.
- For agent mode, use `--agent-root` when required.

Sudo blocked because no-new-privileges:

- Recreate the runtime container with `--allow-sudo`.

Container exists with different flags:

- Remove and recreate the runtime container:

```bash
./codex-container rm
./codex-container start
```

Check status/logs:

```bash
./codex-container status
./codex-container logs
```

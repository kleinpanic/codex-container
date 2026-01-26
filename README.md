# Codex Container

Run the OpenAI Codex CLI in a clean, repeatable Docker environment with **workspace mounting**, **automatic `.env` injection**, and **persistent Codex config/state** across sessions.

This repo gives you a single command (`codex-container`) that behaves like a “Codex runtime” you can use across projects without polluting your host machine.

---

## Features

- **Codex-first UX**
  - `codex-container --search …` just works: *leading flags default to `codex`*.
- **Workspace mounting + correct working directory**
  - Mount any folder to `/workspace`
  - Automatically mirrors your host subdirectory as the container working directory when possible.
- **Automatic `.env` injection**
  - If your project has a `.env`, it is automatically loaded into the container environment (or you can provide one explicitly).
- **Persistent configuration**
  - Codex config/state persists under your host config dir (`~/.config/codex-container/...`) and survives rebuilds.
  - Includes a seeded default config (`codex.config.toml`) copied into persistent storage on first run.
- **Optional host `~/.codex` passthrough**
  - If you already have Codex set up on the host, you can mount that state directly.
- **Quality-of-life**
  - Persistent bash history stored under `/config/history`
  - Global npm packages are preserved via a Docker volume

---

## Quick Start

### 1) Build the image

```bash
./codex-container --build
````

### 2) Run Codex for your current directory

```bash
./codex-container
```

### 3) Run in a specific project workspace

```bash
./codex-container -w /path/to/project
```

### 4) Run Codex with flags (leading flags default to Codex)

```bash
./codex-container --search
./codex-container --full-auto --search
```

---

## Installation

### Local usage (recommended during development)

Just run it from the repo:

```bash
chmod +x ./codex-container ./entrypoint.sh
./codex-container --build
```

### Install into PATH (symlink)

This keeps your wrapper in one place while still being callable from anywhere:

```bash
sudo ln -sf "$(pwd)/codex-container" /usr/local/bin/codex-container
```

> If you use the symlink approach, `--build` should still work correctly as long as the wrapper resolves the real script directory.

---

## Usage

### Codex runs

```bash
# Default behavior (runs codex)
./codex-container

# Run codex explicitly
./codex-container --codex --search

# Leading flags default to codex
./codex-container --search
./codex-container --full-auto --search

# Use a custom env file
./codex-container --env-file /path/to/.env --search
```

### Shell / tools

```bash
# Drop into a shell inside the container
./codex-container --shell

# Run an arbitrary command inside the container
./codex-container npm list
./codex-container node script.js
./codex-container --npx cowsay hello
```

### Container management

```bash
./codex-container --status
./codex-container --logs
./codex-container --stop
./codex-container --clean
./codex-container --build
```

### Debugging the Docker invocation

```bash
./codex-container --debug --search
```

---

## `.env` Autoload Behavior

If you do **not** provide `--env-file`, the wrapper tries to load:

1. `.env` in your **current directory** (if your current directory is inside the workspace), otherwise
2. `.env` at the **workspace root**.

This `.env` file is passed using Docker’s `--env-file`, so variables become real environment variables inside the container and are visible to Codex and anything it launches.

---

## Persistence & Where Things Live

By default, config persists on the host under:

* **Host:** `~/.config/codex-container/config`
* **Container:** mounted to `/config`

Persistent subpaths:

* `/config/codex`
  Codex state/config. On first run, `codex.config.toml` is copied into:

  * `/config/codex/config.toml`

* `/config/npm`
  npm config/cache (symlinked to `/home/codex/.npm`)

* `/config/history`
  Persistent bash history:

  * `/config/history/bash_history`

Global npm installs persist via Docker volume:

* `codex-npm-global` → `/home/codex/.npm-global`

---

## Optional: Mount Host `~/.codex`

If you want the container to use your host’s Codex auth/config directly:

```bash
./codex-container --host-codex-dir --search
```

This mounts:

* Host: `~/.codex`
* Container: `/home/codex/.codex`

If you don’t use this option, Codex state is persisted in `/config/codex` instead.

---

## Environment Variables

These are mostly wrapper controls and passthrough helpers:

### Wrapper controls

* `CODEX_WORKSPACE` — default workspace directory
* `CODEX_CONFIG` — default config directory
* `CODEX_IMAGE` — docker image name/tag override
* `OPENAI_API_KEY` — API key (also supported via `/config/openai_key`)
* `GIT_USER_NAME` — sets global git user.name inside container
* `GIT_USER_EMAIL` — sets global git user.email inside container

### Host context passthrough (always injected)

* `CODEX_HOST_PWD` — your host working directory
* `CODEX_HOST_WORKSPACE` — resolved host workspace root
* `CODEX_HOST_RELATIVE` — host subdirectory relative to workspace (used to set container workdir)

---

## Codex Configuration (`codex.config.toml`)

This repo includes `codex.config.toml` as a **template**.

On first run, the container copies it to:

* `/config/codex/config.toml` (persistent)

You can edit the persistent config at:

* `~/.config/codex-container/config/codex/config.toml`

Tip: keep project-specific secrets out of this file and use `.env` instead.

---

## Directory Structure

```
codex-container/
├── Dockerfile
├── docker-compose.yml
├── codex-container
├── entrypoint.sh
├── codex.config.toml
├── Makefile
├── SETUP_GUIDE.txt
└── README.md
```

---

## License

MIT (see `LICENSE`).


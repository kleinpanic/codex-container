# Codex Container Makefile
# Convenient commands for container management

VERSION := $(shell cat VERSION 2>/dev/null)

.PHONY: help build run shell start stop rm clean status logs install install-user install-user-copy uninstall uninstall-user install-symlink reinstall reinstall-user prune-images completions ci-local package compose-up compose-down compose-logs dev-rebuild test smoke version-check

# Default target
help:
	@echo "Codex Container - Make Commands"
	@echo "==============================="
	@echo ""
	@echo "  make build        - Build the Docker image"
	@echo "  make run          - Run codex in current directory"
	@echo "  make start        - Start persistent runtime container"
	@echo "  make shell        - Open interactive shell"
	@echo "  make stop         - Stop runtime container"
	@echo "  make rm           - Remove runtime container"
	@echo "  make clean        - Remove container and image"
	@echo "  make status       - Show container status"
	@echo "  make logs         - Show container logs"
	@echo "  make install-user - Install wrapper symlink to ~/.local/bin"
	@echo "  make install-user-copy - Install wrapper copy to ~/.local/bin"
	@echo "  make uninstall-user - Remove wrapper from ~/.local/bin"
	@echo "  make install      - Install wrapper to /usr/local/bin"
	@echo "  make uninstall    - Remove wrapper from /usr/local/bin"
	@echo "  make install-symlink - Install symlink to /usr/local/bin"
	@echo "  make prune-images - Remove old codex-container images (keeps current version)"
	@echo "  make ci-local     - Run local CI checks without Docker"
	@echo "  make package      - Create distributable tar.gz archive"
	@echo "  make smoke        - Build + run smoke tests"
	@echo "  make version-check - Verify version consistency"
	@echo ""
	@echo "Docker Compose Commands:"
	@echo "  make compose-up   - Start services with docker compose"
	@echo "  make compose-down - Stop services with docker compose"
	@echo "  make compose-logs - Show docker compose logs"
	@echo ""

# Build Docker image
build:
	@echo "Building Codex Container image..."
	@./codex-container --build

# Run container
run:
	@./codex-container

# Start persistent container
start:
	@./codex-container start

# Open interactive shell
shell:
	@./codex-container shell

# Stop container
stop:
	@./codex-container stop

# Remove container
rm:
	@./codex-container rm

# Clean everything
clean:
	@./codex-container clean

# Show status
status:
	@./codex-container status

# Show logs
logs:
	@./codex-container logs

# Install wrapper script (system)
install:
	@echo "Installing codex-container to /usr/local/bin..."
	@chmod +x codex-container
	@if [ "$$EUID" -ne 0 ]; then \
		sudo install -Dm755 codex-container /usr/local/bin/codex-container 2>/dev/null || \
			{ sudo mkdir -p /usr/local/bin && sudo install -m 755 codex-container /usr/local/bin/codex-container; }; \
	else \
		install -Dm755 codex-container /usr/local/bin/codex-container 2>/dev/null || \
			{ mkdir -p /usr/local/bin && install -m 755 codex-container /usr/local/bin/codex-container; }; \
	fi
	@echo "Installed: /usr/local/bin/codex-container"

# Install wrapper script (user-local)
install-user:
	@echo "Installing codex-container symlink to $$HOME/.local/bin..."
	@mkdir -p "$$HOME/.local/bin"
	@ln -sf "$(PWD)/codex-container" "$$HOME/.local/bin/codex-container"
	@echo "Symlinked: $$HOME/.local/bin/codex-container -> $(PWD)/codex-container"
	@case ":$$PATH:" in \
		*:"$$HOME/.local/bin":*) ;; \
		*) echo "Note: $$HOME/.local/bin is not on PATH. Add it to your shell profile."; \
	esac

install-user-copy:
	@echo "Installing codex-container copy to $$HOME/.local/bin..."
	@chmod +x codex-container
	@install -Dm755 codex-container "$$HOME/.local/bin/codex-container" 2>/dev/null || \
		{ mkdir -p "$$HOME/.local/bin" && install -m 755 codex-container "$$HOME/.local/bin/codex-container"; }
	@echo "Installed: $$HOME/.local/bin/codex-container"
	@case ":$$PATH:" in \
		*:"$$HOME/.local/bin":*) ;; \
		*) echo "Note: $$HOME/.local/bin is not on PATH. Add it to your shell profile."; \
	esac

uninstall-user:
	@rm -f "$$HOME/.local/bin/codex-container"
	@echo "Removed: $$HOME/.local/bin/codex-container (if it existed)"

uninstall:
	@if [ "$$EUID" -ne 0 ]; then \
		sudo rm -f /usr/local/bin/codex-container; \
	else \
		rm -f /usr/local/bin/codex-container; \
	fi
	@echo "Removed: /usr/local/bin/codex-container (if it existed)"

install-symlink:
	@echo "Installing codex-container symlink to /usr/local/bin..."
	@if [ "$$EUID" -ne 0 ]; then \
		sudo ln -sf "$(PWD)/codex-container" /usr/local/bin/codex-container; \
	else \
		ln -sf "$(PWD)/codex-container" /usr/local/bin/codex-container; \
	fi
	@echo "Symlinked: /usr/local/bin/codex-container -> $(PWD)/codex-container"

reinstall-user: uninstall-user install-user

reinstall: uninstall install

prune-images:
	@./codex-container prune-images

completions:
	@echo "Completions live in ./completions"
	@echo "Bash: source completions/codex-container.bash"
	@echo "Zsh: add ./completions to fpath or copy completions/_codex-container"

ci-local:
	@bash -n codex-container entrypoint.sh scripts/*.sh
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck codex-container entrypoint.sh scripts/*.sh; \
	else \
		echo "shellcheck not installed; skipping"; \
	fi
	@./scripts/check-version.sh
	@./scripts/no-docker-tests.sh

# Create distributable package
package:
	@echo "Creating distribution package..."
	@mkdir -p dist
	@tar -czf dist/codex-container-v$(VERSION).tar.gz \
		--transform 's,^,codex-container/,' \
		Dockerfile \
		Dockerfile.agent \
		docker-compose.yml \
		codex-container \
		entrypoint.sh \
		README.md \
		USAGE.md \
		Makefile \
		.env.example \
		.dockerignore \
		VERSION \
		CHANGELOG.md
	@echo "Package created: dist/codex-container-v$(VERSION).tar.gz"
	@echo "Size: $$(du -h dist/codex-container-v$(VERSION).tar.gz | cut -f1)"

# Docker Compose commands
compose-up:
	@CODEX_VERSION=$(VERSION) docker compose up -d
	@echo "Services started. Attach with: docker attach $${CODEX_CONTAINER_NAME:-codex-container-runtime}"

compose-down:
	@CODEX_VERSION=$(VERSION) docker compose down
	@echo "Services stopped"

compose-logs:
	@CODEX_VERSION=$(VERSION) docker compose logs -f

# Development helpers
dev-rebuild:
	@$(MAKE) clean
	@$(MAKE) build
	@$(MAKE) shell

# Test the container
test: smoke

smoke:
	@./scripts/smoke.sh

version-check:
	@./scripts/check-version.sh

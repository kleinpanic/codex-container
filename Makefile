# Codex Container Makefile
# Convenient commands for container management

VERSION := $(shell cat VERSION 2>/dev/null)

.PHONY: help build run shell start stop rm clean status logs install package compose-up compose-down compose-logs dev-rebuild test smoke version-check

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
	@echo "  make install      - Install wrapper script to /usr/local/bin"
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
	@./codex-container --clean

# Show status
status:
	@./codex-container --status

# Show logs
logs:
	@./codex-container --logs

# Install wrapper script
install:
	@echo "Installing codex-container to /usr/local/bin..."
	@chmod +x codex-container
	@sudo ln -sf $(PWD)/codex-container /usr/local/bin/codex-container
	@echo "Installation complete. You can now use 'codex-container' from anywhere."

# Create distributable package
package:
	@echo "Creating distribution package..."
	@tar -czf ../codex-container-v$(VERSION).tar.gz \
		--transform 's,^,codex-container/,' \
		Dockerfile \
		docker-compose.yml \
		codex-container \
		entrypoint.sh \
		README.md \
		Makefile \
		.env.example \
		.dockerignore \
		VERSION \
		CHANGELOG.md
	@echo "Package created: ../codex-container-v$(VERSION).tar.gz"
	@echo "Size: $$(du -h ../codex-container-v$(VERSION).tar.gz | cut -f1)"

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

# Codex Container Makefile
# Convenient commands for container management

.PHONY: help build run shell stop clean status logs install package

# Default target
help:
	@echo "Codex Container - Make Commands"
	@echo "==============================="
	@echo ""
	@echo "  make build       - Build the Docker image"
	@echo "  make run         - Run container in current directory"
	@echo "  make shell       - Open interactive shell"
	@echo "  make stop        - Stop and remove container"
	@echo "  make clean       - Remove container and image"
	@echo "  make status      - Show container status"
	@echo "  make logs        - Show container logs"
	@echo "  make install     - Install wrapper script to /usr/local/bin"
	@echo "  make package     - Create distributable tar.gz archive"
	@echo ""
	@echo "Docker Compose Commands:"
	@echo "  make compose-up   - Start services with docker-compose"
	@echo "  make compose-down - Stop services with docker-compose"
	@echo "  make compose-logs - Show docker-compose logs"
	@echo ""

# Build Docker image
build:
	@echo "Building Codex Container image..."
	@./codex-container --build

# Run container
run:
	@./codex-container

# Open interactive shell
shell:
	@./codex-container --shell

# Stop container
stop:
	@./codex-container --stop

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
	@echo "✓ Installation complete. You can now use 'codex-container' from anywhere."

# Create distributable package
package:
	@echo "Creating distribution package..."
	@tar -czf ../codex-container-v1.0.0.tar.gz \
		--transform 's,^,codex-container/,' \
		Dockerfile \
		docker-compose.yml \
		codex-container \
		entrypoint.sh \
		README.md \
		Makefile \
		.env.example \
		.dockerignore
	@echo "✓ Package created: ../codex-container-v1.0.0.tar.gz"
	@echo "  Size: $$(du -h ../codex-container-v1.0.0.tar.gz | cut -f1)"

# Docker Compose commands
compose-up:
	@docker-compose up -d
	@echo "✓ Services started. Attach with: docker attach codex-container-runtime"

compose-down:
	@docker-compose down
	@echo "✓ Services stopped"

compose-logs:
	@docker-compose logs -f

# Development helpers
dev-rebuild:
	@$(MAKE) clean
	@$(MAKE) build
	@$(MAKE) shell

# Test the container
test:
	@echo "Testing Codex Container..."
	@./codex-container --version
	@./codex-container --status
	@echo "✓ Tests passed"

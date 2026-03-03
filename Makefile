#----------------------------------------------------------------------
# File: Makefile
# Info: Makefile for managing dotfiles installation and cleanup
# Author: Adam Brauns (@AdamBrauns)
#----------------------------------------------------------------------

.PHONY: help install uninstall dry-run check clean verbose

.DEFAULT_GOAL := help

SCRIPT := ./install.sh

# Auto-generate help from target comments with ##
help: ## Show this help message
	@echo "Dotfiles Management"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

install: ## Install dotfiles interactively
	@$(SCRIPT)

verbose: ## Install with verbose output
	@$(SCRIPT) --verbose

uninstall: ## Remove all dotfiles symlinks
	@$(SCRIPT) --uninstall

dry-install: ## Preview installation changes
	@$(SCRIPT) --dry-run --verbose

dry-uninstall: ## Preview uninstallation changes
	@$(SCRIPT) --uninstall --dry-run --verbose

check: ## Verify dependencies are installed
	@command -v ln >/dev/null 2>&1 && \
		command -v mkdir >/dev/null 2>&1 && \
		command -v chmod >/dev/null 2>&1 && \
		command -v date >/dev/null 2>&1 && \
		command -v readlink >/dev/null 2>&1 && \
		echo "✓ All dependencies available" || \
		echo "✗ Missing dependencies - run script to see details"

clean: ## Remove backup files created by installer
	@echo "Searching for backup files..."
	@find ~ -maxdepth 2 -name "*.backup.*" -type f 2>/dev/null | while read -r f; do \
		echo "  Removing: $$f"; \
		rm "$$f"; \
	done || echo "  No backup files found"
	@echo "✓ Cleanup complete"

.SILENT: help

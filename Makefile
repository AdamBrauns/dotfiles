#----------------------------------------------------------------------
# File: Makefile
# Info: Makefile for managing dotfiles installation and cleanup
# Author: Adam Brauns (@AdamBrauns)
#----------------------------------------------------------------------

.PHONY: help install uninstall dry-install dry-uninstall check clean verbose lint

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

dry-install: ## Preview installation changes (pass VERBOSE=1 for detail)
	@$(SCRIPT) --dry-run $(if $(VERBOSE),--verbose,)

dry-uninstall: ## Preview uninstallation changes (pass VERBOSE=1 for detail)
	@$(SCRIPT) --uninstall --dry-run $(if $(VERBOSE),--verbose,)

check: ## Verify dependencies are installed
	@for cmd in ln mkdir chmod date readlink; do \
		command -v $$cmd >/dev/null 2>&1 || { echo "✗ Missing: $$cmd"; exit 1; }; \
	done && echo "✓ All dependencies available"

lint: ## Run shellcheck on install.sh
	@shellcheck install.sh && echo "✓ shellcheck passed"

clean: ## Remove backup files created by installer
	@echo "Searching for backup files..."; \
	files=$$(find ~ ~/.config ~/.gnupg ~/.ssh -maxdepth 1 -name "*.backup.*" -type f 2>/dev/null); \
	if [ -z "$$files" ]; then \
		echo "  No backup files found"; \
	else \
		echo "$$files" | while IFS= read -r f; do \
			echo "  Removing: $$f"; rm "$$f"; \
		done; \
		echo "✓ Cleanup complete"; \
	fi

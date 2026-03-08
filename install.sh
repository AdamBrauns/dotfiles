#!/usr/bin/env bash

# MIT License
# Copyright (c) 2025 Adam Brauns
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

#----------------------------------------------------------------------
# Dotfiles Installation Script
# Author: Adam Brauns (@AdamBrauns)
# Description: Symlinks dotfiles from this repo to $HOME
#----------------------------------------------------------------------

set -u # Exit on undefined variables

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Global flags
VERBOSE=false
DRY_RUN=false
UNINSTALL=false

# Tracking counters
LINKS_CREATED=0
LINKS_SKIPPED=0
LINKS_FAILED=0
BACKUPS_CREATED=0
LINKS_REMOVED=0

# Security constants
readonly DIR_PERMISSIONS=700
readonly FILE_PERMISSIONS=600

# Show usage information
show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Symlinks dotfiles from this repository to \$HOME.

OPTIONS:
    -h, --help       Show this help message
    -v, --verbose    Show detailed information during installation
    -d, --dry-run    Preview changes without making them
    -u, --uninstall  Remove all dotfiles symlinks

EXAMPLES:
    $(basename "$0")                        # Interactive installation
    $(basename "$0") --verbose              # Show all info messages
    $(basename "$0") --dry-run              # Preview what would be installed
    $(basename "$0") --uninstall            # Remove all dotfiles symlinks
    $(basename "$0") --dry-run --uninstall  # Preview what would be uninstalled

EOF
  exit 0
}

# Logging functions
log_info() {
  if [[ "$VERBOSE" == true ]]; then
    echo -e "${BLUE}[INFO]${NC} $1"
  fi
}

log_success() {
  echo -e "${GREEN}[PASS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERRO]${NC} $1"
}

log_dry_run() {
  echo -e "${YELLOW}[DRYR]${NC} $1"
}

# Check for required dependencies
check_dependencies() {
  log_info "Checking dependencies..."
  local missing=()
  local required_commands=("ln" "mkdir" "chmod" "date" "readlink")

  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required dependencies: ${missing[*]}"
    log_error "Please install the missing commands and try again."
    exit 1
  fi

  log_info "All dependencies are available."
}

# Cross-platform readlink that resolves symlinks
resolve_link() {
  local target="$1"

  # Try readlink -f (Linux)
  if readlink -f "$target" 2>/dev/null; then
    return 0
  fi

  # Fall back to manual resolution (macOS)
  local link
  link=$(readlink "$target" 2>/dev/null) || {
    echo "$target"
    return 0
  }

  # If relative path, make it absolute
  if [[ "$link" != /* ]]; then
    link="$(dirname "$target")/$link"
  fi

  echo "$link"
}

# Create symlink with backup
create_symlink() {
  local source="$1"
  local target="$2"

  # Validate source exists
  if [[ ! -e "$source" && ! -d "$source" ]]; then
    log_error "Source does not exist: $source"
    ((LINKS_FAILED++))
    return 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would link: $target -> $source"
    return 0
  fi

  # Create parent directory if it doesn't exist
  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    # If it's already a symlink
    local current_source
    current_source=$(resolve_link "$target")
    if [[ "$current_source" == "$source" ]]; then
      log_info "Already linked: $target"
      ((LINKS_SKIPPED++))
      return 0
    else
      log_warning "Symlink exists but points elsewhere: $target -> $current_source"
      if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would prompt to replace symlink"
        return 0
      fi
      read -p "Replace it? (y/N) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping: $target"
        ((LINKS_SKIPPED++))
        return 0
      fi
      rm "$target"
    fi
  elif [[ -e "$target" || -d "$target" ]]; then
    # If file/directory exists
    log_warning "File/directory already exists: $target"
    if [[ "$DRY_RUN" == true ]]; then
      log_dry_run "Would prompt to backup and replace: $target"
      return 0
    fi
    read -p "Backup and replace? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      local backup
      backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
      mv "$target" "$backup"
      ((BACKUPS_CREATED++))
      log_success "Backed up to: $backup"
    else
      log_info "Skipping: $target"
      ((LINKS_SKIPPED++))
      return 0
    fi
  fi

  ln -s "$source" "$target"
  ((LINKS_CREATED++))
  log_success "Linked: $target -> $source"
}

# Install optional config file with .example fallback
install_optional_config() {
  local source="$1"
  local target="$2"
  local example="${source}.example"

  if [[ -f "$source" ]]; then
    create_symlink "$source" "$target"
  else
    log_warning "$(basename "$source") not found. Copy $(basename "$example") and customize it."
  fi
}

# Set secure permissions on sensitive directories
ensure_secure_directory() {
  local dir="$1"
  if [[ "$DRY_RUN" == true ]]; then
    if [[ ! -d "$dir" ]]; then
      log_dry_run "Would create directory with permissions $DIR_PERMISSIONS: $dir"
    else
      log_dry_run "Would set permissions $DIR_PERMISSIONS on $dir"
    fi
    return 0
  fi
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    chmod "$DIR_PERMISSIONS" "$dir"
    log_info "Created directory with permissions $DIR_PERMISSIONS: $dir"
  else
    chmod "$DIR_PERMISSIONS" "$dir"
    log_info "Set permissions $DIR_PERMISSIONS on $dir"
  fi
}

# Set secure permissions on sensitive files
ensure_secure_file() {
  local file="$1"
  if [[ "$DRY_RUN" == true ]]; then
    if [[ -f "$file" ]]; then
      log_dry_run "Would set permissions $FILE_PERMISSIONS on $file"
    fi
    return 0
  fi
  if [[ -f "$file" ]]; then
    chmod "$FILE_PERMISSIONS" "$file"
    log_info "Set permissions $FILE_PERMISSIONS on $file"
  fi
}

# Remove a symlink if it points to dotfiles directory
remove_symlink() {
  local target="$1"

  if [[ ! -L "$target" ]]; then
    log_info "Not a symlink, skipping: $target"
    ((LINKS_SKIPPED++))
    return 0
  fi

  local current_source
  current_source=$(resolve_link "$target")

  # Check if it points to our dotfiles directory
  if [[ "$current_source" != "$DOTFILES_DIR"* ]]; then
    log_warning "Symlink does not point to dotfiles, skipping: $target"
    ((LINKS_SKIPPED++))
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would remove: $target -> $current_source"
    return 0
  fi

  rm "$target"
  ((LINKS_REMOVED++))
  log_success "Removed: $target"
}

# Uninstall all dotfiles symlinks
uninstall() {
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}=== DRY RUN MODE - No changes will be made ===${NC}"
    echo ""
  fi
  log_info "Starting dotfiles uninstallation..."

  # Define all symlinks that may have been created
  local symlinks=(
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.bash_aliases"
    "$HOME/.bash_env"
    "$HOME/.bash_env_secret"
    "$HOME/.shellcheckrc"
    "$HOME/.scripts"
    "$HOME/.gitconfig"
    "$HOME/.gitconfig.personal"
    "$HOME/.gitconfig.work"
    "$HOME/.vimrc"
    "$HOME/.tmux.conf"
    "$HOME/.Brewfile"
    "$HOME/.config/alacritty"
    "$HOME/.config/rectangle"
    "$HOME/.config/ruff"
    "$HOME/.config/starship.toml"
    "$HOME/.deck.yaml"
    "$HOME/.gnupg/gpg-agent.conf"
    "$HOME/.ssh/config"
  )

  log_info "Checking ${#symlinks[@]} potential symlinks..."

  for link in "${symlinks[@]}"; do
    if [[ -e "$link" || -L "$link" ]]; then
      remove_symlink "$link"
    else
      log_info "Does not exist, skipping: $link"
    fi
  done

  # Print summary
  echo ""
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}=== DRY RUN COMPLETE ===${NC}"
  else
    echo -e "${BLUE}=== UNINSTALL SUMMARY ===${NC}"
    echo -e "${RED}Removed:${NC}  $LINKS_REMOVED symlinks"
    echo -e "${YELLOW}Skipped:${NC}  $LINKS_SKIPPED files"
    echo ""

    if [[ $LINKS_REMOVED -gt 0 ]]; then
      log_success "Dotfiles uninstalled successfully!"
    else
      log_warning "No dotfiles symlinks were found to remove."
    fi
  fi
}

# Installation
install() {
  # Check dependencies first
  check_dependencies

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}=== DRY RUN MODE - No changes will be made ===${NC}"
    echo ""
  fi
  log_info "Starting dotfiles installation from: $DOTFILES_DIR"

  # Bash files
  log_info "Installing Bash configuration..."
  create_symlink "$DOTFILES_DIR/bash/bashrc" "$HOME/.bashrc"
  create_symlink "$DOTFILES_DIR/bash/bash_profile" "$HOME/.bash_profile"
  create_symlink "$DOTFILES_DIR/bash/bash_aliases" "$HOME/.bash_aliases"
  create_symlink "$DOTFILES_DIR/bash/bash_env" "$HOME/.bash_env"
  create_symlink "$DOTFILES_DIR/bash/shellcheckrc" "$HOME/.shellcheckrc"
  install_optional_config "$DOTFILES_DIR/bash/bash_env_secret.local" "$HOME/.bash_env_secret"

  # Scripts
  log_info "Installing scripts..."
  create_symlink "$DOTFILES_DIR/scripts" "$HOME/.scripts"

  # Git files
  log_info "Installing Git configuration..."
  install_optional_config "$DOTFILES_DIR/git/gitconfig.local.gitconfig" "$HOME/.gitconfig"
  install_optional_config "$DOTFILES_DIR/git/gitconfig.personal.local.gitconfig" "$HOME/.gitconfig.personal"
  install_optional_config "$DOTFILES_DIR/git/gitconfig.work.local.gitconfig" "$HOME/.gitconfig.work"

  # Vim
  log_info "Installing Vim configuration..."
  create_symlink "$DOTFILES_DIR/vim/vimrc" "$HOME/.vimrc"

  # Tmux
  log_info "Installing Tmux configuration..."
  create_symlink "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

  # Homebrew
  log_info "Installing Homebrew configuration..."
  create_symlink "$DOTFILES_DIR/homebrew/Brewfile" "$HOME/.Brewfile"

  # .config directory contents
  log_info "Installing .config applications..."
  create_symlink "$DOTFILES_DIR/alacritty" "$HOME/.config/alacritty"
  create_symlink "$DOTFILES_DIR/rectangle" "$HOME/.config/rectangle"
  create_symlink "$DOTFILES_DIR/ruff" "$HOME/.config/ruff"
  create_symlink "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

  # Deck (Kong)
  log_info "Installing Deck configuration..."
  install_optional_config "$DOTFILES_DIR/deck/deck.local.yaml" "$HOME/.deck.yaml"

  # GnuPG
  log_info "Installing GnuPG configuration..."
  ensure_secure_directory "$HOME/.gnupg"
  create_symlink "$DOTFILES_DIR/gnupg/gpg-agent.conf" "$HOME/.gnupg/gpg-agent.conf"

  # SSH config
  log_info "Installing SSH configuration..."
  ensure_secure_directory "$HOME/.ssh"
  install_optional_config "$DOTFILES_DIR/ssh/config.local" "$HOME/.ssh/config"
  ensure_secure_file "$HOME/.ssh/config"

  # Print summary
  echo ""
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}=== DRY RUN COMPLETE ===${NC}"
  else
    if [[ $LINKS_FAILED -gt 0 ]]; then
      log_error "Installation completed with errors. Check the output above."
    else
      log_success "Dotfiles installation complete!"
      log_info "Note: Restart your shell or run 'source ~/.bashrc' to apply changes."
    fi

    echo ""

    echo -e "${BLUE}=== INSTALLATION SUMMARY ===${NC}"
    echo -e "${GREEN}Created:${NC}  $LINKS_CREATED symlinks"
    echo -e "${YELLOW}Skipped:${NC}  $LINKS_SKIPPED files"
    echo -e "${BLUE}Backups:${NC}  $BACKUPS_CREATED files"
    if [[ $LINKS_FAILED -gt 0 ]]; then
      echo -e "${RED}Failed:${NC}   $LINKS_FAILED symlinks"
      exit 1
    fi
  fi
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h | --help)
        show_help
        ;;
      -v | --verbose)
        VERBOSE=true
        shift
        ;;
      -d | --dry-run)
        DRY_RUN=true
        shift
        ;;
      -u | --uninstall)
        UNINSTALL=true
        shift
        ;;
      *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information."
        exit 1
        ;;
    esac
  done
}

# Main entry point
main() {
  parse_args "$@"

  if [[ "$UNINSTALL" == true ]]; then
    uninstall
  else
    install
  fi
}

# Run main function
main "$@"

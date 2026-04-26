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

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

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

# Symlink map: "type|relative_source|absolute_target"
#   type "required" — always link; error if source is missing
#   type "optional" — link only if source exists (e.g. local/secret files)
SYMLINK_MAP=(
  "required|alacritty|$HOME/.config/alacritty"
  "required|bash/bash_aliases|$HOME/.bash_aliases"
  "required|bash/bash_env|$HOME/.bash_env"
  "optional|bash/bash_env_secret.local|$HOME/.bash_env_secret"
  "required|bash/bash_profile|$HOME/.bash_profile"
  "required|bash/bashrc|$HOME/.bashrc"
  "required|bash/shellcheckrc|$HOME/.shellcheckrc"
  "required|claude/CLAUDE.md|$HOME/.claude/CLAUDE.md"
  "optional|deck/deck.local.yaml|$HOME/.deck.yaml"
  "optional|git/gitconfig.local.gitconfig|$HOME/.gitconfig"
  "optional|git/gitconfig.personal.local.gitconfig|$HOME/.gitconfig.personal"
  "optional|git/gitconfig.work.local.gitconfig|$HOME/.gitconfig.work"
  "required|gnupg/gpg-agent.conf|$HOME/.gnupg/gpg-agent.conf"
  "required|homebrew/Brewfile|$HOME/.Brewfile"
  "required|rectangle|$HOME/.config/rectangle"
  "required|ruff|$HOME/.config/ruff"
  "required|scripts|$HOME/.scripts"
  "optional|ssh/config.local|$HOME/.ssh/config"
  "required|starship/starship.toml|$HOME/.config/starship.toml"
  "required|tmux/tmux.conf|$HOME/.tmux.conf"
  "required|vim/vimrc|$HOME/.vimrc"
)

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

# Cross-platform symlink resolution: prefers realpath, falls back to readlink -f,
# then manually resolves relative links (needed on older macOS without coreutils).
resolve_link() {
  local target="$1"

  if command -v realpath &>/dev/null; then
    realpath "$target" 2>/dev/null && return
  fi

  if readlink -f "$target" 2>/dev/null; then
    return
  fi

  # Manual fallback for macOS without coreutils
  local link
  link=$(readlink "$target" 2>/dev/null) || { echo "$target"; return; }

  if [[ "$link" != /* ]]; then
    link="$(dirname "$target")/$link"
  fi

  echo "$link"
}

# Create symlink with backup
create_symlink() {
  local source="$1"
  local target="$2"

  if [[ ! -e "$source" ]]; then
    log_error "Source does not exist: $source"
    LINKS_FAILED=$(( LINKS_FAILED + 1 ))
    return 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would link: $target -> $source"
    return 0
  fi

  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    local current_source
    current_source=$(resolve_link "$target")
    if [[ "$current_source" == "$source" ]]; then
      log_info "Already linked: $target"
      LINKS_SKIPPED=$(( LINKS_SKIPPED + 1 ))
      return 0
    fi
    log_warning "Symlink exists but points elsewhere: $target -> $current_source"
    read -p "Replace it? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log_info "Skipping: $target"
      LINKS_SKIPPED=$(( LINKS_SKIPPED + 1 ))
      return 0
    fi
    rm "$target"
  elif [[ -e "$target" ]]; then
    log_warning "File/directory already exists: $target"
    read -p "Backup and replace? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      local backup
      backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
      mv "$target" "$backup"
      BACKUPS_CREATED=$(( BACKUPS_CREATED + 1 ))
      log_success "Backed up to: $backup"
    else
      log_info "Skipping: $target"
      LINKS_SKIPPED=$(( LINKS_SKIPPED + 1 ))
      return 0
    fi
  fi

  ln -s "$source" "$target"
  LINKS_CREATED=$(( LINKS_CREATED + 1 ))
  log_success "Linked: $target -> $source"
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
  mkdir -p "$dir"
  chmod "$DIR_PERMISSIONS" "$dir"
  log_info "Set permissions $DIR_PERMISSIONS on $dir"
}

# Set secure permissions on sensitive files
ensure_secure_file() {
  local file="$1"
  if [[ "$DRY_RUN" == true ]]; then
    [[ -f "$file" ]] && log_dry_run "Would set permissions $FILE_PERMISSIONS on $file"
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
    LINKS_SKIPPED=$(( LINKS_SKIPPED + 1 ))
    return 0
  fi

  local current_source
  current_source=$(resolve_link "$target")

  if [[ "$current_source" != "$DOTFILES_DIR"* ]]; then
    log_warning "Symlink does not point to dotfiles, skipping: $target"
    LINKS_SKIPPED=$(( LINKS_SKIPPED + 1 ))
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would remove: $target -> $current_source"
    return 0
  fi

  rm "$target"
  LINKS_REMOVED=$(( LINKS_REMOVED + 1 ))
  log_success "Removed: $target"
}

# Uninstall all dotfiles symlinks
uninstall() {
  [[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}=== DRY RUN MODE - No changes will be made ===${NC}\n"
  log_info "Starting dotfiles uninstallation..."
  log_info "Checking ${#SYMLINK_MAP[@]} potential symlinks..."

  for entry in "${SYMLINK_MAP[@]}"; do
    local target="${entry##*|}"
    if [[ -e "$target" || -L "$target" ]]; then
      remove_symlink "$target"
    else
      log_info "Does not exist, skipping: $target"
    fi
  done

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
  check_dependencies

  [[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}=== DRY RUN MODE - No changes will be made ===${NC}\n"
  log_info "Starting dotfiles installation from: $DOTFILES_DIR"

  # Ensure secure directories exist before linking into them
  ensure_secure_directory "$HOME/.gnupg"
  ensure_secure_directory "$HOME/.ssh"

  for entry in "${SYMLINK_MAP[@]}"; do
    local type="${entry%%|*}"
    local rest="${entry#*|}"
    local rel_source="${rest%%|*}"
    local target="${rest##*|}"
    local source="$DOTFILES_DIR/$rel_source"

    if [[ "$type" == "optional" ]]; then
      if [[ -f "$source" ]]; then
        create_symlink "$source" "$target" || true
      else
        log_warning "$(basename "$source") not found — copy the .example and customize it."
      fi
    else
      create_symlink "$source" "$target" || true
    fi
  done

  # Ensure SSH config has correct permissions after linking
  ensure_secure_file "$HOME/.ssh/config"

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
  echo ""

  if [[ "$UNINSTALL" == true ]]; then
    uninstall
  else
    install
  fi
}

# Run main function
main "$@"

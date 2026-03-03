# Dotfiles

Personal dotfiles configuration for macOS/Linux development environments.

## 📁 Structure

```
dotfiles/
├── alacritty/         # Terminal emulator config + themes
├── bash/              # Bash shell configuration
├── deck/              # Kong Deck configuration
├── firefox/           # Firefox browser configuration
├── git/               # Git configuration (with .example templates)
├── gnupg/             # GnuPG configuration
├── homebrew/          # Brewfile for package management
├── rectangle/         # Rectangle window management config
├── ruff/              # Ruff Python linter configuration
├── scripts/           # Utility scripts
├── ssh/               # SSH configuration templates
├── starship/          # Starship cross-shell prompt config
├── tmux/              # Tmux terminal multiplexer configuration
├── vim/               # Vim configuration
├── vscode/            # VS Code settings
├── .gitignore         # Git ignore rules
├── install.sh         # Installation script
├── LICENSE            # MIT License
├── Makefile           # Make targets for easy management
└── README.md
```

## 🚀 Installation

### Quick Start

```bash
# Clone the repository
git clone https://github.com/AdamBrauns/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Preview what will be installed (recommended first step)
make dry-run

# Install dotfiles
make install
# or run directly: ./install.sh
```

### What the installer does:

- Checks for required dependencies before starting
- Creates symlinks from this repo to your `$HOME` directory
- Backs up existing files with timestamps (e.g., `.bashrc.backup.20260111_120000`)
- Sets proper permissions for SSH and GnuPG directories
- Prompts before overwriting existing configurations
- Continues installing even if some files fail
- Shows a summary of what was created, skipped, or failed

### First-time setup:

1. **Git configuration**: Copy and customize environment-specific configs:
   ```bash
   cp git/gitconfig.local.example.gitconfig git/gitconfig.local.gitconfig
   cp git/gitconfig.personal.local.example.gitconfig git/gitconfig.personal.local.gitconfig
   cp git/gitconfig.work.local.example.gitconfig git/gitconfig.work.local.gitconfig
   # Edit these files with your personal information
   ```

2. **SSH configuration**: Copy and customize your SSH config:
   ```bash
   cp ssh/config.local.example ssh/config.local
   # Edit ssh/config.local with your identity files and usernames
   ```

3. **Bash secrets** (optional): Copy and customize environment variables:
   ```bash
   cp bash/bash_env_secret.local.example bash/bash_env_secret.local
   # Edit bash/bash_env_secret.local with your environment-specific settings
   ```

4. **Deck configuration** (optional): Copy and customize Kong Deck config:
   ```bash
   cp deck/deck.local.example.yaml deck/deck.local.yaml
   # Edit deck/deck.local.yaml with your Kong settings
   ```

5. **SSH keys**: Add your SSH keys to `~/.ssh/` (they won't be tracked)

6. **Source your shell**:
   ```bash
   source ~/.bashrc
   # or restart your terminal
   ```

## 🎯 Using Make Commands

The included Makefile provides convenient shortcuts:

```bash
make              # Show available commands
make install      # Install dotfiles interactively
make verbose      # Install with detailed output
make uninstall    # Remove all dotfiles symlinks
make dry-run      # Preview installation without changes
make check        # Verify dependencies are available
make clean        # Remove backup files
```

### Install Script Options

You can also run the install script directly with these options:

```bash
./install.sh              # Interactive installation
./install.sh --verbose    # Show detailed information
./install.sh --dry-run    # Preview without making changes
./install.sh --uninstall  # Remove all symlinks
./install.sh --help       # Show usage information
```

## 🔧 Customization

### Adding new dotfiles

1. Add the file to the appropriate directory (e.g., `bash/new_config`)
2. Update [install.sh](install.sh) to create the symlink
3. Commit and push your changes

### Environment-specific configuration

For machine-specific settings, use the `.example` pattern:
- Keep sensitive/personal data in `.gitignore`d files
- Commit `.example` templates for reference
- Use conditional includes in main configs

## 📝 Manual Installation

If you prefer manual installation:

```bash
# Link bash files
ln -s ~/dotfiles/bash/bashrc ~/.bashrc
ln -s ~/dotfiles/bash/bash_profile ~/.bash_profile
ln -s ~/dotfiles/bash/bash_aliases ~/.bash_aliases
ln -s ~/dotfiles/bash/bash_env ~/.bash_env

# Link git config
ln -s ~/dotfiles/git/gitconfig ~/.gitconfig

# Link vim config
ln -s ~/dotfiles/vim/vimrc ~/.vimrc

# Link tmux config
ln -s ~/dotfiles/tmux/tmux.conf ~/.tmux.conf

# Link .config directory apps
ln -s ~/dotfiles/alacritty ~/.config/alacritty
ln -s ~/dotfiles/rectangle ~/.config/rectangle
ln -s ~/dotfiles/ruff ~/.config/ruff
ln -s ~/dotfiles/starship/starship.toml ~/.config/starship.toml

# And so on...
```

## 🔒 Security Notes

- **Never commit private keys** (SSH, GPG) to this repository
- Personal git configurations are ignored by `.gitignore`
- SSH directory permissions are automatically set to `700`
- GnuPG directory permissions are automatically set to `700`

## 🛠️ Maintenance

### Updating dotfiles

```bash
cd ~/dotfiles
git pull
make install  # Re-run to install any new files
```

### Uninstalling

```bash
# Preview what would be removed
make dry-uninstall

# Uninstall all dotfiles symlinks
make uninstall
# or: ./install.sh --uninstall
```

### Cleaning up

```bash
# Remove backup files created during installation
make clean
```

## 📄 License

Copyright © 2025 Adam Brauns

This project is licensed under the [MIT License](LICENSE).

## 👤 Author

**Adam Brauns** ([@AdamBrauns](https://github.com/AdamBrauns))

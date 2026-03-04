# My dotfiles

Configuration files for macOS and Linux workstations. A single entrypoint script detects the OS and runs the appropriate bootstrap.

Based on [Dotfiles: Best way to store in a bare git repository](https://www.atlassian.com/git/tutorials/dotfiles) from Atlassian's blog.

## Getting started

```bash
git clone --bare git@github.com:thisfrontenddev/dotfiles.git $HOME/.cfg

# Define the alias in the current shell scope:
alias dot='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# Checkout the actual content from the bare repository to your $HOME:
dot checkout

# If checkout fails due to existing files, back them up:
mkdir -p .dotfiles-backup && \
dot checkout 2>&1 | egrep "\s+\." | awk '{print $1}' | \
xargs -I{} mv {} .dotfiles-backup/{}

# Re-run the check out if you had problems:
dot checkout

# Hide untracked files:
dot config --local status.showUntrackedFiles no
```

Run the setup:
```bash
./setup.sh
```

## Structure

```
setup.sh                    # Entrypoint — detects OS and runs the right bootstrap
Brewfile                    # macOS: full Homebrew bundle (formulae + casks)
Brewfile.common             # Shared: CLI-only formulae for both platforms
scripts/
  bootstrap.sh              # macOS bootstrap
  bootstrap-linux.sh        # Linux bootstrap (Fedora, Ubuntu/Debian, Arch)
  homebrew.sh               # macOS Homebrew installer
  rust.sh                   # Rust toolchain setup
  xcode-setup.sh            # macOS Xcode CLI tools
  macosdefaults.sh          # macOS system defaults
  optimize-*.sh             # macOS optimizations
.config/
  zsh/                      # Cross-platform zsh configuration
    .zshenv, .zshrc         # Symlinked from $HOME
    init.zsh                # Main loader
    env.zsh                 # Environment variables
    lib/                    # Modular config (path, history, completions, etc.)
    aliases/                # Alias files
    functions/              # Autoloaded functions
  git/                      # Git configuration (cross-platform)
  starship.toml             # Starship prompt config
  tmux/tmux.conf            # Tmux configuration
  ghostty/config            # Ghostty terminal config
  alacritty/                # Alacritty terminal config
  fastfetch/                # System info display config
```

## Notes

- Some changes need a full reboot to take effect
- On macOS, some programs need Accessibility permissions
- On Linux, log out and back in after changing the default shell to zsh
- Run `tmux` then press `prefix+I` to install tmux plugins

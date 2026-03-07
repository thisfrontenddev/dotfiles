# Dotfiles

Configuration files for my two machines, managed as a [bare git repo](https://www.atlassian.com/git/tutorials/dotfiles).

| Machine | OS | WM / DE | Terminal |
|---|---|---|---|
| MacBook Pro M1 | macOS | AeroSpace | Ghostty + tmux |
| Desktop (RTX 4070 Ti Super) | Fedora 43 | Sway + GNOME | Ghostty + tmux |

## Quick start

### Fresh machine

```bash
# 1. Clone the bare repo
git clone --bare git@github.com:thisfrontenddev/dotfiles.git $HOME/.cfg

# 2. Define the alias for this session
alias dot='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# 3. Checkout files (back up conflicts if any)
dot checkout 2>/dev/null || {
  mkdir -p $HOME/.dotfiles-backup
  dot checkout 2>&1 | grep -E "^\s+" | awk '{print $1}' | \
    xargs -I{} mv {} $HOME/.dotfiles-backup/{}
  dot checkout
}

# 4. Hide untracked files
dot config --local status.showUntrackedFiles no

# 5. Run setup (detects OS automatically)
./setup.sh
```

### Existing machine

```bash
dot pull
./setup.sh   # idempotent — safe to re-run
```

## Repo structure

```
setup.sh                          # Entrypoint — detects OS, runs the right bootstrap

scripts/
  linux/
    bootstrap.sh                  # Full Linux bootstrap (packages, fonts, shell, Fedora setup)
    setup.sh                      # Fedora-specific: Nix, GNOME/Sway, Snapper, Rust, hardening
    install-apps.sh               # DNF, Flatpak, COPR, AppImage installs
    install-drivers.sh            # NVIDIA + RPM Fusion
    harden.sh                     # Firewall, DNS-over-TLS, sysctl, fail2ban, auto-updates
    setup-arctis-nova-pro.sh      # SteelSeries headset (PipeWire virtual sinks)
    setup-gaming.sh               # Steam + compatibility stack
    install-cybrland.sh           # CYBRland theme setup
    cybrwall.sh                   # Wallpaper switcher (rofi picker)
  macos/
    bootstrap.sh                  # macOS bootstrap (Xcode, Homebrew, defaults, security)
    homebrew.sh                   # Homebrew installer + bundle
    cleanup.sh                    # System cleanup (caches, logs, trash)
    macosdefaults.sh              # macOS system defaults (Finder, Dock, etc.)
    optimize-network.sh           # Network tuning
    optimize-security.sh          # Security hardening
    optimize-spotlight.sh         # Spotlight indexing
    optimize-sysctl.sh            # Kernel limits
    xcode-setup.sh                # Xcode CLI tools
  shared/
    setup-nix.sh                  # Nix + Home Manager install + apply
    rust.sh                       # Rust toolchain via rustup
    audio-switch.sh               # Audio output/input switcher (rofi + wpctl)
    generate-rofi-genericnames.sh # Rofi desktop file ID display

Brewfile                          # macOS Homebrew bundle (CLI tools + casks)
```

## Configuration

```
.config/
  zsh/                            # Shell (cross-platform)
    .zshenv                       # Entry: XDG vars, sources env.zsh
    .zshrc                        # Sources init.zsh, fastfetch, startup timing
    init.zsh                      # Loader: lib/, functions/, aliases/, completions/
    env.zsh                       # Cargo env, secrets (untracked)
    lib/
      path.zsh                    # OS-aware PATH (macOS vs Linux)
      history.zsh                 # History settings (50k, dedup, shared)
      completions.zsh             # Completion init + styling
      options.zsh                 # Shell options (auto_cd, glob_dots, etc.)
      starship.zsh                # Starship prompt init
      fnm.zsh                     # fnm (Node version manager) init
      profile.zsh                 # Login-shell extras (OrbStack on macOS)
    aliases/
      common.zsh                  # dot, tmux, eza, podman, claude
      git.zsh                     # git shortcuts (g, gst, gp, please, again)
      convert-images.zsh          # Image conversion aliases (jpg2avif, etc.)
    functions/
      convert-images              # Batch image conversion (autoloaded)
      utils.zsh                   # mktouch helper
  git/
    config                        # Git config: SSH signing, aliases, histogram diff
    ignore                        # Global gitignore
  ghostty/config                  # Terminal: CYBRland palette, tmux keybinds (super key)
  tmux/tmux.conf                  # Tmux config
  starship.toml                   # Prompt theme
  home-manager/
    flake.nix                     # Nix flake (auto-detects x86_64-linux / aarch64-darwin)
    home.nix                      # Shared CLI tools: bat, eza, fzf, gh, starship, tmux, etc.

  # Linux-only
  sway/config                     # Sway WM (Alt keybinds, per-monitor workspaces)
  waybar/                         # Status bar (Catppuccin Mocha, custom scripts)
  rofi/                           # App launcher theme
  swaync/                         # Notification center
  pipewire/                       # PipeWire config (app renaming, virtual sinks)
  logitech/                       # G915 TKL LED control (HID++ Python tool)

  # macOS-only
  aerospace/aerospace.toml        # Tiling WM
  yabai/yabairc                   # Alt tiling WM config
  alacritty/                      # Terminal (+ themes)
```

## Package management

Tools are installed through different channels depending on the platform:

| What | macOS | Linux (Fedora) |
|---|---|---|
| CLI tools (bat, eza, fzf, gh, starship...) | Homebrew (`Brewfile`) | Nix Home Manager (`home.nix`) |
| GUI apps | Homebrew casks (`Brewfile`) | DNF, Flatpak, COPR (`install-apps.sh`) |
| System packages (compilers, libs) | Xcode CLI tools | DNF (`bootstrap.sh`) |
| Node.js | fnm (via Homebrew) | fnm (via Nix) |
| Rust | rustup (via Homebrew) | rustup (via Nix) |

### Adding a new CLI tool

1. Add to `.config/home-manager/home.nix` (Linux uses this)
2. Add to `Brewfile` (macOS uses this)
3. Run `home-manager switch --flake ~/.config/home-manager` or `brew bundle`

## Key aliases

| Alias | Command | Notes |
|---|---|---|
| `dot` | `git --git-dir=$HOME/.cfg/ --work-tree=$HOME` | Dotfiles management |
| `attach` | `tmux new -A -s personal` | Attach/create tmux session |
| `ll` | `eza --git --long --icons --all` | Pretty file listing |
| `please` | `git push --force-with-lease` | Safe force push |
| `again` | `git commit --amend --no-edit` | Amend last commit |
| `docker` | `podman` | Rootless containers |

## Post-setup steps

- **tmux plugins:** open tmux, press `prefix + I` to install plugins
- **GNOME extensions:** log out and back in for full activation
- **Sway:** available at GDM login screen after setup
- **Git signing:** SSH key must exist at `~/.ssh/id_ed25519` — run `ssh-keygen -t ed25519` if needed

## SSH config

Hardened defaults for all hosts: Ed25519 keys, curve25519 key exchange, ChaCha20-Poly1305 ciphers, no agent forwarding. See `.ssh/config`.

## Notes

- All setup scripts are idempotent — safe to run multiple times
- `secrets.zsh` is gitignored — create at `~/.config/zsh/secrets.zsh` for tokens/keys
- `.zshenv` and `.zshrc` in `$HOME` are symlinks to `.config/zsh/`
- The `dot` alias uses `/usr/bin/git` to avoid Homebrew/Nix git interfering with the bare repo

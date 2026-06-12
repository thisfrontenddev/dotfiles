# Dotfiles

Configuration files for my two machines, managed as a [bare git repo](https://www.atlassian.com/git/tutorials/dotfiles).

| Machine | OS | WM / DE | Terminal |
|---|---|---|---|
| MacBook Pro M1 | macOS | AeroSpace | Ghostty + tmux |
| Desktop (RTX 5070 Ti) | Arch Linux | Hyprland / Sway | Ghostty + tmux |

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
setup.sh                          # Entrypoint — detects OS, then on Linux dispatches by /etc/os-release

scripts/
  fedora/
    bootstrap.sh                  # Fedora bootstrap (packages, fonts, shell, then runs setup.sh)
    setup.sh                      # Fedora-specific: Nix, GNOME/Sway, Snapper, Rust, hardening
    setup-nix.sh                  # Nix + Home Manager install + apply (Fedora-only)
    install-apps.sh               # DNF, Flatpak, COPR, AppImage installs
    install-drivers.sh            # NVIDIA + RPM Fusion
    harden.sh                     # firewalld, DNS-over-TLS, sysctl, fail2ban, auto-updates
    setup-arctis-nova-pro.sh      # SteelSeries headset (PipeWire virtual sinks)
    setup-gaming.sh               # Steam + compatibility stack
    setup-g915.sh                 # Logitech G915 TKL lighting (orchestrates ~/.config/g915 assets)
    install-cybrland.sh           # CYBRland theme setup
    cybrwall.sh                   # Wallpaper switcher (rofi picker)
    accent-picker.py              # macOS-style press-and-hold accent popup for Wayland
    lib.sh                        # Helpers: distro detect, pkg_install w/ Fedora→Arch mapping
  arch/
    bootstrap.sh                  # Arch bootstrap (shell-focused: fish + starship + default shell)
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
    rust.sh                       # Rust toolchain via rustup (cross-OS)
    audio-switch.sh               # Audio output/input switcher (rofi + wpctl)
    generate-rofi-genericnames.sh # Rofi desktop file ID display
    setup-obsidian-git.sh         # Obsidian vault git auto-sync

Brewfile                          # macOS Homebrew bundle (CLI tools + casks)
```

**Distro dispatch on Linux**: `setup.sh` reads `/etc/os-release` and runs `scripts/fedora/bootstrap.sh` or `scripts/arch/bootstrap.sh`. The Arch bootstrap currently covers the shell (fish + starship + default shell); broader parity (fonts, tmux, apps, drivers, hardening) is still pending.

## Configuration

```
.config/
  fish/                           # Shell (cross-platform) — current default
    conf.d/                       # 00-env, abbreviations, starship, fnm, orbstack
    functions/                    # dot, convert-images, mktouch, swaymsg, fish_greeting
  zsh/                            # Shell — kept as a fallback during the fish migration
    .zshenv                       # Entry: XDG vars, startup timing
    .zshrc                        # Sources init.zsh, fastfetch, startup timing
    .zprofile                     # Login-shell (sourced once)
    init.zsh                      # Loader: lib/, functions/, aliases/, completions/
    lib/
      env.zsh                     # OS-aware PATH, cargo, secrets (merged path+env)
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
      mktouch                     # Create file + parent dirs (autoloaded)
  git/
    config                        # Git config: SSH signing, aliases, histogram diff
    ignore                        # Global gitignore
  ghostty/config                  # Terminal: CYBRland palette, tmux keybinds (super key)
  tmux/tmux.conf                  # Tmux config
  starship.toml                   # Prompt theme
  home-manager/                   # Fedora-only — Nix installs CLI tools that dnf ships stale
    flake.nix                     # Nix flake (auto-detects x86_64-linux / aarch64-darwin)
    home.nix                      # CLI tool list (bat, eza, fzf, gh, starship, tmux...) for Fedora

  # Linux-only
  sway/config                     # Sway WM (Alt keybinds, per-monitor workspaces)
  waybar/                         # Status bar (Catppuccin Mocha, custom scripts)
  rofi/                           # App launcher theme
  swaync/                         # Notification center
  pipewire/                       # PipeWire config (app renaming, virtual sinks)
  g915/                           # G915 TKL LED control (HID++ Python tool, udev, setup)

  # macOS-only
  aerospace/aerospace.toml        # Tiling WM
  yabai/yabairc                   # Alt tiling WM config
  alacritty/                      # Terminal (+ themes)
```

## Package management

Tools are installed through different channels depending on the platform:

| What | macOS | Fedora | Arch |
|---|---|---|---|
| CLI tools (bat, eza, fzf, gh, starship...) | Homebrew (`Brewfile`) | Nix Home Manager (`home.nix`) | paru (Arch repos + AUR) |
| GUI apps | Homebrew casks (`Brewfile`) | DNF, Flatpak, COPR (`install-apps.sh`) | paru, Flatpak |
| System packages (compilers, libs) | Xcode CLI tools | DNF (`bootstrap.sh`) | pacman |
| Node.js | fnm (via Homebrew) | fnm (via Nix) | fnm (`pacman -S fnm`) |
| Rust | rustup (via Homebrew) | rustup (via Nix) | rustup (`pacman -S rustup`) |

Nix is intentionally Fedora-only: dnf often ships stale dev-tool versions, so Nix earns its complexity there. Brew and paru both cover the same tool list cleanly, so adding Nix on top would just be redundancy.

### Optional macOS casks

The macOS Homebrew bootstrap asks about a small set of optional casks before running `brew bundle`: `whatsapp`, `notion`, `little-snitch`, `micro-snitch`, `linear-linear`, `spline`, and `obs`.
Set `BREW_OPTIONAL_CASKS` to skip the prompts.

Examples:

```bash
BREW_OPTIONAL_CASKS=whatsapp,notion,obs ./setup.sh
BREW_OPTIONAL_CASKS=all ./setup.sh
BREW_OPTIONAL_CASKS="" ./setup.sh
```

### Adding a new CLI tool

1. Add to `Brewfile` (macOS uses this)
2. Add to `.config/home-manager/home.nix` (Fedora uses this — run `home-manager switch --flake ~/.config/home-manager` after)
3. Add to your future `scripts/arch/` install list (Arch uses paru)

## Key aliases

On fish these are **abbreviations** (they expand inline as you type); the equivalent zsh aliases remain in `.config/zsh/` as a fallback. Shortcuts with logic (`dot`, `swaymsg`, `convert-images`) are fish functions.

| Shortcut | Expands to | Notes |
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
- `secrets.zsh` / `secrets.fish` are untracked — create at `~/.config/zsh/secrets.zsh` or `~/.config/fish/secrets.fish` for tokens/keys
- `.zshenv` and `.zshrc` in `$HOME` are symlinks to `.config/zsh/`
- The `dot` alias uses `/usr/bin/git` to avoid Homebrew/Nix git interfering with the bare repo

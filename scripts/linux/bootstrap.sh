#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$(cd "$SCRIPTS_DIR/../shared" && pwd)"

echo "=== Linux Bootstrap ==="

# ── Detect distro ──
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  DISTRO="$ID"
else
  echo "Cannot detect distro. Exiting."
  exit 1
fi

# ── Step 1: Install system packages ──
echo "==> Installing system packages..."
case "$DISTRO" in
  fedora)
    # Base packages only — full Fedora installs handled by linux/setup.sh
    sudo dnf install -y --skip-unavailable \
      zsh git gcc gcc-c++ cmake fontconfig curl
    ;;
  ubuntu|debian|pop)
    sudo apt update
    sudo apt install -y \
      zsh git gcc g++ cmake ninja-build clang lld \
      golang-go default-jdk \
      podman \
      neovim tmux fzf \
      htop btop ripgrep fd-find bat jq \
      strace ltrace \
      fastfetch imagemagick ffmpeg \
      pipx snapper \
      fontconfig
    ;;
  arch|endeavouros|manjaro)
    sudo pacman -Syu --noconfirm --needed \
      zsh git gcc cmake ninja clang lld \
      go jdk-openjdk \
      podman podman-compose \
      neovim tmux fzf \
      htop btop ripgrep fd bat jq yq \
      strace ltrace hyperfine tokei \
      fastfetch imagemagick ffmpeg \
      pipx snapper \
      fontconfig
    ;;
  *)
    echo "Unsupported distro: $DISTRO — install packages manually."
    ;;
esac

# ── Step 2: Nix + Home Manager (declarative package management) ──
echo "==> Setting up Nix..."
bash "$SHARED_DIR/setup-nix.sh"

# ── Step 3: Clone dotfiles (if not already present) ──
if [[ ! -d "$HOME/.cfg" ]]; then
  echo "==> Cloning dotfiles..."
  git clone --bare git@github.com:thisfrontenddev/dotfiles.git "$HOME/.cfg"
  alias dot="/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME"
  dot checkout 2>/dev/null || {
    echo "Backing up conflicting dotfiles..."
    mkdir -p "$HOME/.dotfiles-backup"
    dot checkout 2>&1 | grep -E "^\s+" | awk '{print $1}' | xargs -I{} mv {} "$HOME/.dotfiles-backup/{}"
    dot checkout
  }
  dot config --local status.showUntrackedFiles no
fi

# ── Step 4: Zsh symlinks ──
echo "==> Setting up zsh symlinks..."
ln -sf "$HOME/.config/zsh/.zshenv" "$HOME/.zshenv"
ln -sf "$HOME/.config/zsh/.zshrc" "$HOME/.zshrc"

SECRETS_FILE="$HOME/.config/zsh/secrets.zsh"
if [[ ! -f "$SECRETS_FILE" ]]; then
  cat > "$SECRETS_FILE" <<'SECRETS'
# Zsh secrets — API keys, tokens, etc.
# This file is sourced by env.zsh and is NOT tracked in dotfiles.
#
# Example:
#   export OPENAI_API_KEY="sk-..."
#   export ANTHROPIC_API_KEY="sk-ant-..."
SECRETS
  echo "  Created $SECRETS_FILE (add your secrets here)"
fi

# ── Step 5: Rust ──
bash "$SHARED_DIR/rust.sh"

# ── Step 6: Create required directories ──
mkdir -p "$HOME/.local/state/zsh"
mkdir -p "$HOME/.cache/zsh"
mkdir -p "$HOME/Pictures/Screenshots"

# ── Step 7: Install fonts ──
echo "==> Installing Nerd Fonts..."
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
for font in JetBrainsMono GeistMono SpaceMono; do
  if [[ ! -d "$FONT_DIR/$font" ]]; then
    echo "  Downloading $font Nerd Font..."
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.tar.xz" \
      | tar -xJf - -C "$FONT_DIR"
  fi
done

# Inter — used as system UI font
if ! ls "$FONT_DIR"/Inter*.ttf &>/dev/null && ! ls "$FONT_DIR"/Inter*.otf &>/dev/null; then
  echo "  Downloading Inter font..."
  INTER_TMP="$(mktemp -d)"
  curl -fsSL "https://github.com/rsms/inter/releases/latest/download/Inter-4.1.zip" -o "$INTER_TMP/inter.zip"
  unzip -qo "$INTER_TMP/inter.zip" -d "$INTER_TMP"
  cp "$INTER_TMP"/Inter*.ttf "$FONT_DIR/" 2>/dev/null || cp "$INTER_TMP"/**/*.ttf "$FONT_DIR/" 2>/dev/null || true
  rm -rf "$INTER_TMP"
fi

fc-cache -f 2>/dev/null || true

# ── Step 8: tmux plugin manager ──
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  echo "==> Installing tmux plugin manager..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# ── Step 9: Set default shell ──
ZSH_PATH="$(command -v zsh)"
if [[ -n "$ZSH_PATH" && "$SHELL" != "$ZSH_PATH" ]]; then
  echo "==> Setting zsh as default shell..."
  chsh -s "$ZSH_PATH"
fi

# ── Step 10: Fedora-specific setup ──
if [[ "$DISTRO" == "fedora" ]]; then
  echo "==> Running Fedora setup..."
  bash "$SCRIPTS_DIR/setup.sh"
fi

echo ""
echo "=== Linux Bootstrap complete! ==="
echo "  • Restart your terminal (or log out/in) to activate zsh"
echo "  • Run 'tmux' then press prefix+I to install tmux plugins"

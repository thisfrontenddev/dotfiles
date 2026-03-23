#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$(cd "$SCRIPTS_DIR/../shared" && pwd)"
source "$SCRIPTS_DIR/lib.sh"

echo "=== Linux Bootstrap ==="

# ── Step 1: Install system packages ──
echo "==> Installing system packages..."
pkg_install zsh git gcc gcc-c++ cmake fontconfig curl

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
mkdir -p "$HOME/.config/zsh/completions"
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
# Auto-install tmux plugins (doesn't require a running tmux session)
if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
  echo "==> Installing tmux plugins..."
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
fi

# ── Step 9: Set default shell ──
ZSH_PATH="$(command -v zsh)"
if [[ -n "$ZSH_PATH" && "$SHELL" != "$ZSH_PATH" ]]; then
  echo "==> Setting zsh as default shell..."
  chsh -s "$ZSH_PATH"
fi

# ── Step 10: Distro-specific setup ──
if [[ "$DISTRO_FAMILY" == "fedora" || "$DISTRO_FAMILY" == "arch" ]]; then
  echo "==> Running $DISTRO_FAMILY setup..."
  bash "$SCRIPTS_DIR/setup.sh"
fi

echo ""
echo "=== Linux Bootstrap complete! ==="
echo "  • Restart your terminal (or log out/in) to activate zsh"
echo "  • Run 'tmux' then press prefix+I to install tmux plugins"

#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$(cd "$SCRIPTS_DIR/../shared" && pwd)"

echo "=== MacBook Bootstrap ==="

# --- Step 1: Xcode CLI Tools (uses existing script) ---
if ! xcode-select -p &>/dev/null; then
  echo "==> Installing Xcode Command Line Tools..."
  bash "$SCRIPTS_DIR/xcode-setup.sh"
fi

# --- Step 2: Homebrew (uses existing script) ---
bash "$SCRIPTS_DIR/homebrew.sh"

# --- Step 3: Clone dotfiles ---
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

# --- Step 4: Shell config symlinks ---
echo "==> Setting up shell config symlinks..."
ln -sf "$HOME/.config/zsh/.zshenv" "$HOME/.zshenv"
ln -sf "$HOME/.config/zsh/.zshrc" "$HOME/.zshrc"

# --- Step 5: Rust (uses existing script) ---
bash "$SHARED_DIR/rust.sh"

# --- Step 6: Create required directories ---
mkdir -p "$HOME/.local/state/zsh"
mkdir -p "$HOME/.cache/zsh"
mkdir -p "$HOME/Screenshots"

# --- Step 7: Apply all optimizations ---
echo "==> Applying macOS defaults..."
bash "$SCRIPTS_DIR/macosdefaults.sh"

echo "==> Applying network optimizations..."
bash "$SCRIPTS_DIR/optimize-network.sh"

echo "==> Applying Spotlight optimizations..."
bash "$SCRIPTS_DIR/optimize-spotlight.sh"

echo "==> Applying security hardening..."
bash "$SCRIPTS_DIR/optimize-security.sh"

# --- Step 8: Set default shell ---
if command -v brew &>/dev/null; then
  BREW_BIN="$(command -v brew)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
  BREW_BIN="/opt/homebrew/bin/brew"
elif [[ -x /usr/local/bin/brew ]]; then
  BREW_BIN="/usr/local/bin/brew"
else
  echo "Homebrew was not found after running homebrew.sh"
  exit 1
fi

BREW_PREFIX="$("$BREW_BIN" --prefix)"
FISH_PATH="$BREW_PREFIX/bin/fish"

if [[ ! -x "$FISH_PATH" ]]; then
  echo "fish was not found at $FISH_PATH after brew bundle install"
  exit 1
fi

if ! grep -qxF "$FISH_PATH" /etc/shells; then
  echo "==> Adding $FISH_PATH to /etc/shells..."
  echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

CURRENT_SHELL="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}' || true)"
CURRENT_SHELL="${CURRENT_SHELL:-${SHELL:-}}"

if [[ "$CURRENT_SHELL" != "$FISH_PATH" ]]; then
  echo "==> Setting fish as default shell..."
  chsh -s "$FISH_PATH"
fi

echo ""
echo "=== Bootstrap complete! Restart your terminal to start using fish. ==="

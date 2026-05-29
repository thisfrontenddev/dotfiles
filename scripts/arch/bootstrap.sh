#!/usr/bin/env bash
# Arch bootstrap — shell-focused starting point.
# Installs fish + starship via paru and makes fish the default shell.
# NOTE: intentionally minimal (shell only). Broader Arch parity (fonts, tmux,
# apps, drivers, hardening) is a separate, later effort.
set -euo pipefail

# ── 1. Packages (paru handles official repos + AUR; run as user, not root) ──
echo "==> Installing fish + starship..."
paru -S --needed --noconfirm fish starship git

# ── 2. Clone dotfiles if absent (normally a no-op; checkout precedes setup) ──
if [[ ! -d "$HOME/.cfg" ]]; then
  echo "==> Cloning dotfiles..."
  git clone --bare git@github.com:thisfrontenddev/dotfiles.git "$HOME/.cfg"
  dot() { /usr/bin/git --git-dir="$HOME/.cfg" --work-tree="$HOME" "$@"; }
  dot checkout 2>/dev/null || {
    echo "Backing up conflicting dotfiles..."
    mkdir -p "$HOME/.dotfiles-backup"
    dot checkout 2>&1 | grep -E "^\s+" | awk '{print $1}' | xargs -I{} mv {} "$HOME/.dotfiles-backup/{}"
    dot checkout
  }
  dot config --local status.showUntrackedFiles no
fi

# ── 3. Make fish the default login shell ──
FISH_PATH="$(command -v fish)"
if [[ -n "$FISH_PATH" ]]; then
  if ! grep -qxF "$FISH_PATH" /etc/shells; then
    echo "==> Adding $FISH_PATH to /etc/shells..."
    echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
  fi
  if [[ "$SHELL" != "$FISH_PATH" ]]; then
    echo "==> Setting fish as default shell..."
    chsh -s "$FISH_PATH"
  fi
fi

# ── 4. Fish secrets template (untracked) ──
SECRETS_FILE="$HOME/.config/fish/secrets.fish"
if [[ ! -f "$SECRETS_FILE" ]]; then
  mkdir -p "$HOME/.config/fish"
  cat > "$SECRETS_FILE" <<'SECRETS'
# Fish secrets — API keys, tokens, etc.
# Sourced by conf.d/00-env.fish; NOT tracked in dotfiles.
#
# Example:
#   set -gx OPENAI_API_KEY "sk-..."
#   set -gx ANTHROPIC_API_KEY "sk-ant-..."
SECRETS
  echo "  Created $SECRETS_FILE"
fi

# ── 5. cybr theming: clone components into the cache + relink (idempotent) ──
if [[ -x "$HOME/scripts/shared/cybr-sync" ]]; then
  echo "==> Syncing cybr theming components..."
  "$HOME/scripts/shared/cybr-sync"
fi

echo ""
echo "=== Arch shell bootstrap complete ==="
echo "  • Log out/in (or open a new terminal) to start using fish"
echo "  • Add secrets to $SECRETS_FILE"

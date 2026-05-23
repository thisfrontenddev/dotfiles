#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${GREEN}[✓] $1${NC}"; }
info() { echo -e "${YELLOW}    → $1${NC}"; }

echo "=== Nix + Home Manager Setup ==="

# ── 1. Install Nix (Determinate installer — supports SELinux) ──
step "Installing Nix"
if command -v nix &>/dev/null; then
  info "Nix already installed ($(nix --version))"
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  info "Nix installed ($(nix --version))"
fi

# ── 2. Ensure Home Manager flake config exists ──
step "Setting up Home Manager"
HM_DIR="$HOME/.config/home-manager"
mkdir -p "$HM_DIR"

if [[ ! -f "$HM_DIR/flake.nix" ]] || [[ ! -f "$HM_DIR/home.nix" ]]; then
  info "flake.nix or home.nix missing — dotfiles checkout may have failed"
  info "Expected files at $HM_DIR/flake.nix and $HM_DIR/home.nix"
  exit 1
fi

# ── 3. Apply Home Manager config ──
step "Applying Home Manager configuration"
nix run home-manager -- switch --flake "$HM_DIR#$(whoami)"
info "Home Manager packages installed"

# ── 4. Set up Node.js via fnm ──
step "Setting up Node.js via fnm"
if command -v fnm &>/dev/null; then
  eval "$(fnm env)"
  if fnm list 2>/dev/null | grep -q "lts-latest"; then
    info "Node LTS already installed"
  else
    fnm install --lts
    info "Node LTS installed"
  fi
  fnm default lts-latest
  info "Node default set to LTS ($(node --version 2>/dev/null))"
else
  info "fnm not found — run Home Manager switch first"
fi

echo ""
echo "=== Nix + Home Manager setup complete! ==="

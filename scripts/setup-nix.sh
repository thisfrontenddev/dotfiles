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

if [[ ! -f "$HM_DIR/flake.nix" ]]; then
  cat > "$HM_DIR/flake.nix" << 'EOF'
{
  description = "Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }: {
    homeConfigurations."void" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home.nix ];
    };
  };
}
EOF
  info "flake.nix created"
else
  info "flake.nix already exists"
fi

if [[ ! -f "$HM_DIR/home.nix" ]]; then
  cat > "$HM_DIR/home.nix" << 'EOF'
{ pkgs, ... }: {
  home.username = "void";
  home.homeDirectory = "/home/void";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # Shell & prompt
    starship
    tmux
    fzf

    # Dev tools
    lazygit
    gh
    commitizen
    cloc
    watchman
    fnm
    rustup
    tldr

    # File & search
    bat
    eza
    ripgrep

    # System info
    fastfetch
    btop
  ];
}
EOF
  info "home.nix created"
else
  info "home.nix already exists"
fi

# ── 3. Apply Home Manager config ──
step "Applying Home Manager configuration"
nix run home-manager -- switch --flake "$HM_DIR"
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

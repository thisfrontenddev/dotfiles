#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${GREEN}[✓] $1${NC}"; }
info() { echo -e "${YELLOW}    → $1${NC}"; }

echo "=== Fedora System Setup ==="

# ── 1. Nix + Home Manager (CLI tools) ──
step "Setting up Nix + Home Manager"
bash "$SCRIPTS_DIR/../shared/setup-nix.sh"

# ── 2. Install packages and apps ──
step "Installing packages and apps"
bash "$SCRIPTS_DIR/install-apps.sh"

# ── 3. Dark mode + system fonts (GNOME only) ──
if command -v gsettings &>/dev/null && [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* || -z "$XDG_CURRENT_DESKTOP" ]]; then
  step "Enabling dark mode and setting system fonts"
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
  gsettings set org.gnome.desktop.interface font-name 'Inter 11'
  gsettings set org.gnome.desktop.interface document-font-name 'Inter 11'
  gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11'
  gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Inter Bold 11'
  info "Dark mode enabled, Inter + JetBrains Mono Nerd Font set"

  # ── 4. Enable GNOME extensions ──
  step "Enabling GNOME extensions"
  gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com 2>/dev/null || true
  gnome-extensions enable blur-my-shell@auber 2>/dev/null || true
  gnome-extensions enable forge@jmmaranan.com 2>/dev/null || true
  info "AppIndicator, Blur My Shell, Forge enabled"

  # ── 5. GNOME workspace + Forge keybindings (dconf) ──
  # Source of truth: ~/.config/dconf/workspace-keybindings.ini
  # Sets 19 workspaces, Alt+1-9/0, Forge tiling keys, clears conflicts
  step "Loading GNOME workspace + Forge keybindings"
  if [[ -f "$HOME/.config/dconf/workspace-keybindings.ini" ]]; then
    dconf load / < "$HOME/.config/dconf/workspace-keybindings.ini"
    info "19 workspaces + Forge keybindings loaded from dconf ini"
  else
    info "WARNING: ~/.config/dconf/workspace-keybindings.ini not found — keybindings not configured"
  fi
else
  step "Skipping GNOME settings (not a GNOME session)"
fi

# ── 6. Default browser ──
step "Setting default browser to Zen"
xdg-mime default app.zen_browser.zen.desktop x-scheme-handler/http
xdg-mime default app.zen_browser.zen.desktop x-scheme-handler/https
xdg-mime default app.zen_browser.zen.desktop text/html
info "Zen Browser set as default"

# ── 7. Snapper (btrfs snapshots) ──
step "Configuring Snapper"
if command -v snapper &>/dev/null; then
  if ! sudo snapper list-configs 2>/dev/null | grep -q "^root"; then
    sudo snapper create-config /
    info "Snapper config created for /"
  else
    info "Snapper root config already exists"
  fi
  if ! sudo snapper list-configs 2>/dev/null | grep -q "^home"; then
    sudo snapper create-config /home
    info "Snapper config created for /home"
  else
    info "Snapper home config already exists"
  fi
else
  info "Snapper not installed — skipping"
fi

# ── 8. Sway setup ──
step "Setting up Sway"

# Patch sway desktop entry for NVIDIA (--unsupported-gpu + WLR_DRM_DEVICES)
SWAY_DESKTOP="/usr/share/wayland-sessions/sway.desktop"
if [[ -f "$SWAY_DESKTOP" ]]; then
  if ! grep -q "unsupported-gpu" "$SWAY_DESKTOP" 2>/dev/null; then
    sudo cp "$SWAY_DESKTOP" "${SWAY_DESKTOP}.bak"
    # Detect NVIDIA GPU card (typically card1 or card2) and set device ordering
    NVIDIA_CARD=$(ls -d /dev/dri/card* 2>/dev/null | while read card; do
      if udevadm info -a "$card" 2>/dev/null | grep -q "nvidia"; then echo "$card"; break; fi
    done)
    OTHER_CARDS=$(ls /dev/dri/card* 2>/dev/null | grep -v "${NVIDIA_CARD:-NONE}" | tr '\n' ':' | sed 's/:$//')
    if [[ -n "$NVIDIA_CARD" && -n "$OTHER_CARDS" ]]; then
      DRM_DEVICES="$NVIDIA_CARD:$OTHER_CARDS"
      sudo sed -i "s|Exec=sway|Exec=env WLR_DRM_DEVICES=$DRM_DEVICES sway --unsupported-gpu|" "$SWAY_DESKTOP"
      info "Sway desktop entry patched: WLR_DRM_DEVICES=$DRM_DEVICES --unsupported-gpu"
    else
      sudo sed -i 's|Exec=sway|Exec=sway --unsupported-gpu|' "$SWAY_DESKTOP"
      info "Sway desktop entry patched with --unsupported-gpu"
    fi
  else
    info "Sway desktop entry already patched"
  fi
fi

# Generate wallpaper from Fedora default (if not already present)
WALLPAPER_DIR="$HOME/.config/sway/wallpapers"
mkdir -p "$WALLPAPER_DIR"
if [[ ! -f "$WALLPAPER_DIR/f43-night.png" ]]; then
  # Try to find a Fedora wallpaper to use, or create a solid color fallback
  FEDORA_WP=$(find /usr/share/backgrounds -name "*night*" -o -name "*f43*" 2>/dev/null | head -1)
  if [[ -n "$FEDORA_WP" ]]; then
    cp "$FEDORA_WP" "$WALLPAPER_DIR/f43-night.png"
    info "Wallpaper copied from $FEDORA_WP"
  elif command -v convert &>/dev/null; then
    convert -size 2560x1440 xc:'#1e1e2e' "$WALLPAPER_DIR/f43-night.png"
    info "Solid Catppuccin Mocha wallpaper generated"
  else
    info "No wallpaper found — set one manually at $WALLPAPER_DIR/f43-night.png"
  fi
fi

# ── 9. Rust toolchain ──
step "Setting up Rust toolchain"
if command -v rustup &>/dev/null; then
  if rustup show active-toolchain &>/dev/null; then
    info "Rust toolchain already configured: $(rustup show active-toolchain | head -1)"
  else
    rustup default stable
    info "Rust stable toolchain installed"
  fi
else
  info "rustup not found — install via home-manager first"
fi

# ── 10. System hardening ──
step "Applying system hardening"
bash "$SCRIPTS_DIR/harden.sh"

echo ""
echo "=== Fedora setup complete! ==="
echo ""
echo -e "${YELLOW}  Log out and back in for:${NC}"
echo "    - GNOME extensions to fully activate"
echo "    - Sway available at GDM login screen"

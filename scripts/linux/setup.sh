#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/lib.sh"

echo "=== Linux System Setup ($DISTRO) ==="

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

if [[ "$DISTRO_FAMILY" == "fedora" ]]; then
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
fi

# Generate wallpaper (if not already present)
WALLPAPER_DIR="$HOME/.config/sway/wallpapers"
mkdir -p "$WALLPAPER_DIR"
if [[ ! -f "$WALLPAPER_DIR/f43-night.png" ]]; then
  if command -v convert &>/dev/null; then
    convert -size 2560x1440 xc:'#1e1e2e' "$WALLPAPER_DIR/f43-night.png"
    info "Solid Catppuccin Mocha wallpaper generated"
  else
    info "No wallpaper found — set one manually at $WALLPAPER_DIR/f43-night.png"
  fi
fi

# ── 9. Sysctl tuning ──
step "Installing sysctl dev workstation tuning"
SYSCTL_SRC="$HOME/.config/sysctl/99-dev-workstation.conf"
SYSCTL_DST="/etc/sysctl.d/99-dev-workstation.conf"
if [[ -L "$SYSCTL_DST" ]] && [[ "$(readlink -f "$SYSCTL_DST")" == "$SYSCTL_SRC" ]]; then
  info "sysctl config already symlinked"
else
  sudo ln -sf "$SYSCTL_SRC" "$SYSCTL_DST"
  sudo sysctl --system >/dev/null 2>&1
  info "sysctl config symlinked and applied"
fi

# ── 10. DNS configuration (Cloudflare DoT + NM dispatcher) ──
step "Deploying DNS configuration"
# systemd-resolved: Cloudflare DNS-over-TLS
RESOLVED_SRC="$HOME/.config/resolved/dns-over-tls.conf"
RESOLVED_DST="/etc/systemd/resolved.conf.d/dns-over-tls.conf"
if [[ -f "$RESOLVED_SRC" ]]; then
  sudo mkdir -p /etc/systemd/resolved.conf.d
  sudo cp "$RESOLVED_SRC" "$RESOLVED_DST"
  sudo systemctl restart systemd-resolved
  info "DNS-over-TLS config deployed and resolved restarted"
else
  info "WARNING: $RESOLVED_SRC not found — skipping"
fi
# NetworkManager dispatcher: enforce Cloudflare on non-VPN connections
NM_SRC="$HOME/.config/networkmanager/99-cloudflare-dns"
NM_DST="/etc/NetworkManager/dispatcher.d/99-cloudflare-dns"
if [[ -f "$NM_SRC" ]]; then
  sudo cp "$NM_SRC" "$NM_DST"
  sudo chmod +x "$NM_DST"
  info "NM Cloudflare DNS dispatcher deployed (skips VPN connections)"
else
  info "WARNING: $NM_SRC not found — skipping"
fi

# ── 11. Btrfs scrub timer ──
step "Installing btrfs scrub timer"
BTRFS_UNITS="$HOME/.config/systemd/system-units"
if findmnt -t btrfs / >/dev/null 2>&1; then
  sudo cp "$BTRFS_UNITS/btrfs-scrub.service" /etc/systemd/system/
  sudo cp "$BTRFS_UNITS/btrfs-scrub.timer" /etc/systemd/system/
  sudo systemctl daemon-reload
  sudo systemctl enable --now btrfs-scrub.timer
  info "btrfs scrub timer installed and enabled (monthly)"
else
  info "Root is not btrfs — skipping"
fi

# ── 11. Flatpak auto-update timer ──
step "Installing Flatpak auto-update timer"
if command -v flatpak &>/dev/null; then
  USER_UNITS="$HOME/.config/systemd/user-units"
  USER_DIR="$HOME/.config/systemd/user"
  mkdir -p "$USER_DIR"
  ln -sf "$USER_UNITS/flatpak-update.service" "$USER_DIR/flatpak-update.service"
  ln -sf "$USER_UNITS/flatpak-update.timer" "$USER_DIR/flatpak-update.timer"
  systemctl --user daemon-reload
  systemctl --user enable --now flatpak-update.timer
  info "Flatpak auto-update timer symlinked and enabled (weekly)"
else
  info "Flatpak not installed — skipping"
fi

# ── 12. Rust toolchain ──
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

# ── 13. Logitech G915 TKL lighting ──
step "Setting up Logitech G915 TKL lighting"
bash "$HOME/.config/g915/setup.sh"

# ── 14. CYBRland theme (wallpapers, sway/waybar dependencies) ──
step "Installing CYBRland theme"
bash "$SCRIPTS_DIR/install-cybrland.sh"

# ── 15. System hardening ──
step "Applying system hardening"
bash "$SCRIPTS_DIR/harden.sh"

# ── 16. Optional: Gaming setup ──
if [[ -f "$SCRIPTS_DIR/setup-gaming.sh" ]]; then
  read -rp "Install gaming tools (Steam, gamemode, mangohud)? [y/N] " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    step "Setting up gaming"
    bash "$SCRIPTS_DIR/setup-gaming.sh"
  fi
fi

# ── 17. Optional: Arctis Nova Pro headset ──
if [[ -f "$SCRIPTS_DIR/setup-arctis-nova-pro.sh" ]]; then
  read -rp "Set up SteelSeries Arctis Nova Pro headset? [y/N] " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    step "Setting up Arctis Nova Pro"
    bash "$SCRIPTS_DIR/setup-arctis-nova-pro.sh"
  fi
fi

echo ""
echo "=== Linux setup complete! ($DISTRO) ==="
echo ""
if command -v gsettings &>/dev/null && [[ "${XDG_CURRENT_DESKTOP:-}" == *"GNOME"* ]]; then
  echo -e "${YELLOW}  Log out and back in for:${NC}"
  echo "    - GNOME extensions to fully activate"
  echo "    - Sway available at GDM login screen"
else
  echo -e "${YELLOW}  Log out and back in to apply all changes.${NC}"
fi

#!/bin/bash
# install-cybrland.sh — Reproducible setup for cybrland theme on Fedora + Sway
# Run: bash ~/scripts/linux/install-cybrland.sh
set -euo pipefail

# Prevent running as root (sudo expands $HOME to /root)
if [ "$(id -u)" -eq 0 ]; then
    echo "Error: Do not run this script with sudo. It will call sudo only when needed."
    exit 1
fi

BACKUP_DIR="$HOME/.config/theme-backup/catppuccin"
WALL_DIR="$HOME/.config/sway/wallpapers/cybrland"
REPO_BASE="https://raw.githubusercontent.com/scherrer-txt/cybrland/main"

FONT_DIR="$HOME/.local/share/fonts"
NERD_FONT_VERSION="v3.3.0"

echo "=== CYBRland Theme Installer ==="

# ─── 0. Install GeistMono Nerd Font ─────────────────────────────
if fc-list | grep -qi "GeistMono Nerd Font"; then
    echo "[0/5] GeistMono Nerd Font already installed."
else
    echo "[0/5] Installing GeistMono Nerd Font ..."
    mkdir -p "$FONT_DIR"
    TMPDIR=$(mktemp -d)
    curl -sL "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/GeistMono.zip" -o "$TMPDIR/GeistMono.zip"
    unzip -qo "$TMPDIR/GeistMono.zip" -d "$FONT_DIR"
    rm -rf "$TMPDIR"
    fc-cache -f
    echo "    GeistMono Nerd Font installed."
fi

# ─── 1. Backup current configs (first run only) ─────────────────
if [ ! -d "$BACKUP_DIR" ]; then
    echo "[1/5] Backing up current configs to $BACKUP_DIR ..."
    mkdir -p "$BACKUP_DIR"
    # Waybar
    [ -d "$HOME/.config/waybar" ] && cp -r "$HOME/.config/waybar" "$BACKUP_DIR/"
    # Sway config
    [ -f "$HOME/.config/sway/config" ] && cp "$HOME/.config/sway/config" "$BACKUP_DIR/sway-config"
    # Mako
    [ -f "$HOME/.config/mako/config" ] && cp "$HOME/.config/mako/config" "$BACKUP_DIR/mako-config"
    # Starship
    [ -f "$HOME/.config/starship.toml" ] && cp "$HOME/.config/starship.toml" "$BACKUP_DIR/"
    # Fastfetch
    [ -f "$HOME/.config/fastfetch/config.jsonc" ] && cp "$HOME/.config/fastfetch/config.jsonc" "$BACKUP_DIR/fastfetch-config.jsonc"
    # Ghostty
    [ -f "$HOME/.config/ghostty/config" ] && cp "$HOME/.config/ghostty/config" "$BACKUP_DIR/ghostty-config"
    # Btop
    [ -d "$HOME/.config/btop" ] && cp -r "$HOME/.config/btop" "$BACKUP_DIR/"
    echo "    Backup complete."
else
    echo "[1/5] Backup already exists, skipping."
fi

# ─── 2. Install dependencies ────────────────────────────────────
echo "[2/5] Installing dependencies ..."
DEPS=(
    rofi-wayland
    SwayNotificationCenter
    playerctl
    python3-gobject
    lm_sensors
)

# Check which are missing
MISSING=()
for dep in "${DEPS[@]}"; do
    if ! rpm -q "$dep" &>/dev/null; then
        MISSING+=("$dep")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "    Installing: ${MISSING[*]}"
    sudo dnf install -y "${MISSING[@]}"
else
    echo "    All dependencies already installed."
fi

# ─── 3. Download wallpapers ─────────────────────────────────────
echo "[3/5] Downloading cybrland wallpapers ..."
mkdir -p "$WALL_DIR"

WALLS=(
    chiyoda-2560x1440.png
    ikebukuro-2560x1440.png
    minato-2560x1440.png
    roppongi-2560x1440.png
    samurai-2560x1440.png
    shibuya-2560x1440.png
    shinjuku-2560x1440.png
    taito-2560x1440.png
    yoyogi-2560x1440.png
)

for wall in "${WALLS[@]}"; do
    if [ ! -f "$WALL_DIR/$wall" ]; then
        echo "    Downloading $wall ..."
        curl -sL "$REPO_BASE/hypr/walls/$wall" -o "$WALL_DIR/$wall"
    fi
done
echo "    Wallpapers ready."

# ─── 4. Set wallpaper in sway config ────────────────────────────
echo "[4/5] Setting wallpaper ..."
FIRST_WALL="$WALL_DIR/shibuya-2560x1440.png"
if [ -f "$FIRST_WALL" ]; then
    sed -i "s|output DP-6 bg .* fill|output DP-6 bg $FIRST_WALL fill|" "$HOME/.config/sway/config"
    sed -i "s|output HDMI-A-2 bg .* fill|output HDMI-A-2 bg $FIRST_WALL fill|" "$HOME/.config/sway/config"
    echo "    Wallpaper set to shibuya."
fi

# ─── 5. Reload services ─────────────────────────────────────────
echo "[5/5] Reloading sway (waybar restarts automatically) ..."
swaymsg reload 2>/dev/null || true
swaync-client -rs 2>/dev/null || true

echo ""
echo "=== CYBRland theme installed! ==="
echo "Revert anytime with: bash ~/scripts/linux/revert-catppuccin.sh"

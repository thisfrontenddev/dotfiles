#!/bin/bash
# revert-catppuccin.sh — Restore Catppuccin Mocha configs from backup
# Run: bash ~/scripts/linux/revert-catppuccin.sh
set -euo pipefail

BACKUP_DIR="$HOME/.config/theme-backup/catppuccin"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: No backup found at $BACKUP_DIR"
    echo "Cannot revert — backup was never created."
    exit 1
fi

echo "=== Reverting to Catppuccin Mocha ==="

# Waybar
if [ -d "$BACKUP_DIR/waybar" ]; then
    echo "  Restoring waybar ..."
    rm -rf "$HOME/.config/waybar"
    cp -r "$BACKUP_DIR/waybar" "$HOME/.config/waybar"
fi

# Sway config
if [ -f "$BACKUP_DIR/sway-config" ]; then
    echo "  Restoring sway config ..."
    cp "$BACKUP_DIR/sway-config" "$HOME/.config/sway/config"
fi

# Mako config (restore + stop swaync)
if [ -f "$BACKUP_DIR/mako-config" ]; then
    echo "  Restoring mako config ..."
    mkdir -p "$HOME/.config/mako"
    cp "$BACKUP_DIR/mako-config" "$HOME/.config/mako/config"
fi

# Starship
if [ -f "$BACKUP_DIR/starship.toml" ]; then
    echo "  Restoring starship ..."
    cp "$BACKUP_DIR/starship.toml" "$HOME/.config/starship.toml"
fi

# Fastfetch
if [ -f "$BACKUP_DIR/fastfetch-config.jsonc" ]; then
    echo "  Restoring fastfetch ..."
    cp "$BACKUP_DIR/fastfetch-config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
fi

# Ghostty
if [ -f "$BACKUP_DIR/ghostty-config" ]; then
    echo "  Restoring ghostty ..."
    cp "$BACKUP_DIR/ghostty-config" "$HOME/.config/ghostty/config"
fi

# Btop
if [ -d "$BACKUP_DIR/btop" ]; then
    echo "  Restoring btop ..."
    rm -rf "$HOME/.config/btop"
    cp -r "$BACKUP_DIR/btop" "$HOME/.config/btop"
fi

# Reload services
echo "  Reloading services ..."

# Stop swaync, start mako
pkill swaync 2>/dev/null || true
sleep 0.3
mako &
disown

# Restart waybar
pkill waybar 2>/dev/null || true
sleep 0.5
waybar &
disown

# Reload sway
swaymsg reload 2>/dev/null || true

echo ""
echo "=== Catppuccin Mocha restored! ==="
echo "You may need to restart ghostty for terminal colors to take effect."

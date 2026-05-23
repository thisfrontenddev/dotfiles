#!/bin/bash
# cybrwall.sh — Switch cybrland wallpaper
# Usage: cybrwall.sh [name]    e.g. cybrwall.sh roppongi
#        cybrwall.sh           (no args = list + pick with rofi)
set -euo pipefail

WALL_DIR="$HOME/.config/sway/wallpapers/cybrland"

# Get available wallpapers (strip path and suffix)
names=()
for f in "$WALL_DIR"/*.png; do
    name=$(basename "$f" | sed 's/-2560x1440\.png//')
    names+=("$name")
done

if [ $# -ge 1 ]; then
    PICK="$1"
else
    # Use rofi to pick
    PICK=$(printf '%s\n' "${names[@]}" | rofi -dmenu -p "wallpaper" 2>/dev/null) || exit 0
fi

WALL="$WALL_DIR/${PICK}-2560x1440.png"
if [ ! -f "$WALL" ]; then
    echo "Not found: $WALL"
    echo "Available: ${names[*]}"
    exit 1
fi

swaymsg "output * bg $WALL fill"
# Persist in sway config
sed -i "s|output DP-6 bg .* fill|output DP-6 bg $WALL fill|" "$HOME/.config/sway/config"
sed -i "s|output HDMI-A-2 bg .* fill|output HDMI-A-2 bg $WALL fill|" "$HOME/.config/sway/config"
echo "Wallpaper set to $PICK"

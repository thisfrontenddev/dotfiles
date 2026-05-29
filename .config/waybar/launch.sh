#!/usr/bin/env bash
# Render waybar config with live connector names, then start waybar.
#
# Bars are pinned by monitor *description* (stable across reboots/driver updates)
# rather than connector name (DP-5 / HDMI-A-2 shift on NVIDIA after a replug or
# driver event), so the bar self-heals: config.jsonc carries @OLED@ / @LENOVO@
# tokens, and this script resolves them to whatever connector each monitor has
# right now before launching.
set -euo pipefail

CFG_DIR="$HOME/.config/waybar"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/waybar"
RUNTIME_CFG="$RUNTIME_DIR/config.jsonc"
mkdir -p "$RUNTIME_DIR"

# Resolve the connector name (e.g. DP-5) for the monitor whose description
# contains the given substring. Uses python3 (not jq) so the bar never depends
# on jq being installed. Prints nothing if the monitor is absent.
conn_for() {
	hyprctl monitors -j | python3 -c '
import json, sys
sub = sys.argv[1]
for m in json.load(sys.stdin):
    if sub in (m.get("description") or ""):
        print(m["name"]); break
' "$1"
}

OLED="$(conn_for 'MO27Q28G')"     # Gigabyte QD-OLED (primary)
LENOVO="$(conn_for 'G27c-10')"    # Lenovo IPS (secondary)

# If a monitor is disconnected, point its bar at an impossible connector so it
# simply doesn't draw (rather than falling back to "all outputs").
sed -e "s/@OLED@/${OLED:-__OLED_OFFLINE__}/g" \
    -e "s/@LENOVO@/${LENOVO:-__LENOVO_OFFLINE__}/g" \
    "$CFG_DIR/config.jsonc" > "$RUNTIME_CFG"

pkill -x waybar 2>/dev/null || true
exec waybar -c "$RUNTIME_CFG" -s "$CFG_DIR/style.css"

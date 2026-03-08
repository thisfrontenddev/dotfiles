#!/usr/bin/env bash
set -euo pipefail

# Setup script for SteelSeries Arctis Nova Pro Wireless on Linux (Fedora)
# Installs: PipeWire virtual sinks, pavucontrol, easyeffects, qpwgraph
# Symlinks: udev rules, nova-chatmix, nova-route from ~/.config/steelseries/
# Creates: systemd user service

NOVA_CHATMIX_BIN="$HOME/.local/bin/nova-chatmix"
NOVA_ROUTE_BIN="$HOME/.local/bin/nova-route"

STEELSERIES_VID="1038"
STEELSERIES_PID="12e0"

echo "=== SteelSeries Arctis Nova Pro Wireless — Linux Setup ==="

# ── Verify device is connected ──
echo ""
echo "==> Checking for Arctis Nova Pro Wireless..."
if lsusb | grep -qi "${STEELSERIES_VID}:${STEELSERIES_PID}"; then
    echo "    Found: $(lsusb | grep -i "${STEELSERIES_VID}:${STEELSERIES_PID}" | head -1)"
else
    echo "    WARNING: Device not detected via USB. Continuing anyway (will work once plugged in)."
fi

# ── Install system packages ──
echo ""
echo "==> Installing system packages..."
sudo dnf install -y --skip-unavailable \
    pavucontrol easyeffects qpwgraph \
    python3-hidapi pipewire-utils \
    hidapi

# ── udev rules for non-root HID access + systemd auto-start ──
echo ""
echo "==> Installing udev rules..."
UDEV_RULE_SRC="$HOME/.config/steelseries/50-nova-pro-wireless.rules"
UDEV_RULE_DST="/etc/udev/rules.d/50-nova-pro-wireless.rules"

if [[ ! -f "$UDEV_RULE_SRC" ]]; then
    echo "    ERROR: Source rule not found at $UDEV_RULE_SRC"
    exit 1
fi

if [[ -L "$UDEV_RULE_DST" ]] && [[ "$(readlink -f "$UDEV_RULE_DST")" == "$UDEV_RULE_SRC" ]]; then
    echo "    udev rules already symlinked"
else
    sudo ln -sf "$UDEV_RULE_SRC" "$UDEV_RULE_DST"
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    echo "    udev rules symlinked and reloaded"
fi

# ── Install nova-chatmix ──
echo ""
echo "==> Installing nova-chatmix..."
NOVA_CHATMIX_SRC="$HOME/.config/steelseries/nova-chatmix"
if [[ ! -f "$NOVA_CHATMIX_SRC" ]]; then
    echo "    ERROR: Missing $NOVA_CHATMIX_SRC"
    exit 1
fi
mkdir -p "$HOME/.local/bin"
if [[ -L "$NOVA_CHATMIX_BIN" ]] && [[ "$(readlink -f "$NOVA_CHATMIX_BIN")" == "$NOVA_CHATMIX_SRC" ]]; then
    echo "    nova-chatmix already symlinked"
else
    ln -sf "$NOVA_CHATMIX_SRC" "$NOVA_CHATMIX_BIN"
    echo "    Symlinked nova-chatmix to $NOVA_CHATMIX_BIN"
fi

# ── systemd user service for nova-chatmix ──
echo ""
echo "==> Installing nova-chatmix systemd service..."
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/nova-chatmix.service" << 'EOF'
[Unit]
Description=ChatMix for SteelSeries Arctis Nova Pro Wireless
After=pipewire.service pipewire-pulse.service wireplumber.service
Requires=wireplumber.service

[Service]
Type=simple
ExecStartPre=/bin/sleep 2
ExecStart=%h/.local/bin/nova-chatmix
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable nova-chatmix.service
echo "    Service installed and enabled"

# ── PipeWire virtual sinks: Game, Chat, Media ──
# All three are persistent PipeWire modules that route to the default output
# nova-chatmix only handles the HID ChatMix dial for Game/Chat volume control
echo ""
echo "==> PipeWire virtual sinks..."
if [[ -f "$HOME/.config/pipewire/pipewire.conf.d/10-nova-virtual-sinks.conf" ]]; then
    echo "    Sink config already present (NovaGame, NovaChat, NovaMedia)"
else
    echo "    ERROR: Missing $HOME/.config/pipewire/pipewire.conf.d/10-nova-virtual-sinks.conf"
    echo "    This file should be part of your dotfiles"
    exit 1
fi

# ── PipeWire pulse rules: rename Electron apps ──
# Electron apps report as "Chromium" to PipeWire — this fixes display names
# and ensures stream-restore remembers per-app sink assignments correctly
echo ""
echo "==> Configuring PipeWire app rename rules..."
mkdir -p "$HOME/.config/pipewire/pipewire-pulse.conf.d"
cat > "$HOME/.config/pipewire/pipewire-pulse.conf.d/50-rename-apps.conf" << 'EOF'
# Rename Electron apps that show up as "Chromium" in pavucontrol
# Add more blocks here for other Electron apps as needed
pulse.rules = [
    {
        matches = [ { application.process.binary = "Cider" } ]
        actions = {
            update-props = {
                application.name = "Cider"
                application.icon_name = "cider"
            }
        }
    }
]
EOF
echo "    Electron app rename rules installed"

# ── App-routing helper script ──
# PipeWire remembers per-app sink assignments via WirePlumber's stream state.
# This helper lets you set them from the CLI. After first assignment, PipeWire
# remembers the choice automatically across reboots.
echo ""
echo "==> Installing nova-route helper..."
NOVA_ROUTE_SRC="$HOME/.config/steelseries/nova-route"
if [[ ! -f "$NOVA_ROUTE_SRC" ]]; then
    echo "    ERROR: Missing $NOVA_ROUTE_SRC"
    exit 1
fi
if [[ -L "$NOVA_ROUTE_BIN" ]] && [[ "$(readlink -f "$NOVA_ROUTE_BIN")" == "$NOVA_ROUTE_SRC" ]]; then
    echo "    nova-route already symlinked"
else
    ln -sf "$NOVA_ROUTE_SRC" "$NOVA_ROUTE_BIN"
    echo "    Symlinked nova-route to $NOVA_ROUTE_BIN"
fi

# ── Clean up any broken WirePlumber configs from previous runs ──
rm -f "$HOME/.config/wireplumber/wireplumber.conf.d/50-nova-routing.conf"
rm -f "$HOME/.config/wireplumber/wireplumber.conf.d/50-nova-app-routing.conf"
rm -rf "$HOME/.config/wireplumber/scripts"

# ── Restart all services ──
echo ""
echo "==> Restarting audio services..."
systemctl --user stop nova-chatmix.service 2>/dev/null || true
systemctl --user restart pipewire pipewire-pulse wireplumber
echo "    PipeWire and WirePlumber restarted"

sleep 3

if ! systemctl --user is-active --quiet wireplumber; then
    echo "    ERROR: WirePlumber failed. Check: journalctl --user -u wireplumber -n 20"
    exit 1
fi
echo "    WirePlumber: active"

systemctl --user restart nova-chatmix.service
sleep 4

if systemctl --user is-active --quiet nova-chatmix; then
    echo "    nova-chatmix: active"
else
    echo "    WARNING: nova-chatmix not running (is headset plugged in?)"
    echo "    It will auto-start when the DAC is connected."
fi

# ── Verify sinks ──
echo ""
echo "==> Verifying audio sinks..."
SINKS=$(pactl list sinks short 2>/dev/null)
ALL_OK=true
for SINK in NovaGame NovaChat NovaMedia; do
    if echo "$SINKS" | grep -q "$SINK"; then
        echo "    $SINK: OK"
    else
        echo "    $SINK: NOT FOUND"
        ALL_OK=false
    fi
done

STEELSERIES_SINK=$(echo "$SINKS" | grep -i "SteelSeries_Arctis_Nova_Pro" | awk '{print $2}')
if [[ -n "$STEELSERIES_SINK" ]]; then
    echo "    Hardware: $STEELSERIES_SINK"
else
    echo "    Hardware: NOT FOUND"
    ALL_OK=false
fi

# ── Done ──
echo ""
echo "============================================="
if $ALL_OK; then
    echo "  Setup complete! All sinks active."
else
    echo "  Setup complete (some sinks missing — check headset connection)."
fi
echo "============================================="
echo ""
echo "  Virtual sinks:"
echo "    NovaGame  → default (games, everything else)"
echo "    NovaChat  → voice apps (Discord, TeamSpeak, Zoom...)"
echo "    NovaMedia → media apps (Cider, Spotify, mpv...)"
echo ""
echo "  Hardware controls:"
echo "    Volume wheel → hardware-level (always works)"
echo "    ChatMix dial → press wheel to toggle, turn to balance Game/Chat"
echo ""
echo "  Assign apps to sinks (one-time, PipeWire remembers):"
echo "    nova-route Discord NovaChat"
echo "    nova-route Cider NovaMedia"
echo "    nova-route firefox NovaGame"
echo "    (or use pavucontrol → Playback tab → output dropdown)"
echo ""
echo "  GUI tools installed:"
echo "    pavucontrol  → per-app volume + sink assignment"
echo "    easyeffects  → parametric EQ, compressor, effects"
echo "    qpwgraph     → visual audio routing patchbay"
echo "============================================="

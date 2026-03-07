#!/usr/bin/env bash
set -euo pipefail

# Setup script for SteelSeries Arctis Nova Pro Wireless on Linux (Fedora)
# Installs: nova-chatmix-linux, PipeWire virtual sinks, pavucontrol, easyeffects, qpwgraph
# Creates: udev rules, systemd user service, PipeWire Media sink, app-routing helper

NOVA_CHATMIX_DIR="$HOME/.local/share/nova-chatmix-linux"
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
UDEV_RULE='SUBSYSTEMS=="usb", ATTRS{idVendor}=="'"${STEELSERIES_VID}"'", ATTRS{idProduct}=="'"${STEELSERIES_PID}"'", TAG+="uaccess", ENV{SYSTEMD_USER_WANTS}="nova-chatmix.service"'

if [[ -f /etc/udev/rules.d/50-nova-pro-wireless.rules ]] && grep -qF "${STEELSERIES_PID}" /etc/udev/rules.d/50-nova-pro-wireless.rules; then
    echo "    udev rules already installed"
else
    echo "$UDEV_RULE" | sudo tee /etc/udev/rules.d/50-nova-pro-wireless.rules >/dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    echo "    udev rules installed and reloaded"
fi

# ── Install nova-chatmix-linux ──
echo ""
echo "==> Installing nova-chatmix-linux..."
if [[ -d "$NOVA_CHATMIX_DIR/.git" ]]; then
    echo "    Updating existing clone..."
    git -C "$NOVA_CHATMIX_DIR" pull --quiet
else
    rm -rf "$NOVA_CHATMIX_DIR"
    git clone https://github.com/Dymstro/nova-chatmix-linux.git "$NOVA_CHATMIX_DIR"
fi

mkdir -p "$HOME/.local/bin"
cp "$NOVA_CHATMIX_DIR/nova-chatmix.py" "$NOVA_CHATMIX_BIN"
chmod +x "$NOVA_CHATMIX_BIN"
echo "    Installed to $NOVA_CHATMIX_BIN"

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

# ── PipeWire virtual sink: Media ──
# nova-chatmix creates NovaGame/NovaChat sinks itself via pw-loopback
# We add a persistent NovaMedia sink for music/videos
echo ""
echo "==> Configuring PipeWire NovaMedia virtual sink..."
mkdir -p "$HOME/.config/pipewire/pipewire.conf.d"
cat > "$HOME/.config/pipewire/pipewire.conf.d/10-nova-media-sink.conf" << 'EOF'
# Persistent "NovaMedia" virtual sink for music/videos/browser
# NovaGame and NovaChat sinks are managed by the nova-chatmix service
context.modules = [
    {
        name = libpipewire-module-loopback
        args = {
            node.description = "NovaMedia"
            capture.props = {
                media.class    = Audio/Sink
                node.name      = NovaMedia
                audio.position = [ FL FR ]
            }
            playback.props = {
                node.name      = nova-media-output
                audio.position = [ FL FR ]
            }
        }
    }
]
EOF
echo "    Created NovaMedia virtual sink"

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
cat > "$NOVA_ROUTE_BIN" << 'ROUTESCRIPT'
#!/usr/bin/env bash
# nova-route — move a running app's audio to a Nova sink
# Usage: nova-route <app-name-substring> <NovaGame|NovaChat|NovaMedia>
# Example: nova-route Discord NovaChat
#          nova-route Cider NovaMedia
#          nova-route firefox NovaGame
#
# PipeWire/WirePlumber remembers the assignment, so you only need to do this once per app.

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: nova-route <app-name> <NovaGame|NovaChat|NovaMedia>"
    echo ""
    echo "Running audio streams:"
    pactl list sink-inputs 2>/dev/null | grep -E "(application.name|application.process.binary)" | \
        sed 's/.*= "\(.*\)"/  \1/' | sort -u
    exit 1
fi

APP="$1"
SINK="$2"

# Verify the sink exists
if ! pactl list sinks short 2>/dev/null | grep -q "$SINK"; then
    echo "ERROR: Sink '$SINK' not found. Available sinks:"
    pactl list sinks short | grep -i nova
    exit 1
fi

# Find matching audio stream(s) by checking each sink-input's properties
MOVED=0
while IFS= read -r idx; do
    [[ -z "$idx" ]] && continue
    PROPS=$(pactl list sink-inputs 2>/dev/null | sed -n "/Sink Input #${idx}/,/Sink Input #/p")
    APP_NAME=$(echo "$PROPS" | grep "application.name" | head -1 | sed 's/.*= "\(.*\)"/\1/')
    APP_BIN=$(echo "$PROPS" | grep "application.process.binary" | head -1 | sed 's/.*= "\(.*\)"/\1/')

    if echo "$APP_NAME" | grep -qi "$APP" || echo "$APP_BIN" | grep -qi "$APP"; then
        pactl move-sink-input "$idx" "$SINK" 2>/dev/null && MOVED=$((MOVED+1))
    fi
done < <(pactl list sink-inputs short 2>/dev/null | awk '{print $1}')

if [[ $MOVED -gt 0 ]]; then
    echo "Moved $MOVED stream(s) matching '$APP' → $SINK"
else
    echo "No running streams found matching '$APP'"
    echo ""
    echo "Running streams:"
    pactl list sink-inputs 2>/dev/null | grep -E "(application.name|application.process.binary)" | \
        sed 's/.*= "\(.*\)"/  \1/' | sort -u
fi
ROUTESCRIPT
chmod +x "$NOVA_ROUTE_BIN"
echo "    Installed nova-route to $NOVA_ROUTE_BIN"

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

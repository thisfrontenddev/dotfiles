#!/usr/bin/env bash
#
# Logitech device setup for Fedora (G915 TKL + G PRO X Superlight)
# Installs: Solaar, Piper
# Configures: udev rule for G915 TKL lighting persistence
#
# Safe to run multiple times — all operations are idempotent.
#
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
skip() { echo -e "${YELLOW}[=]${NC} $1 (already done)"; }
error() { echo -e "${RED}[x]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Pre-flight checks ---
if [[ ! -f /etc/fedora-release ]]; then
    error "This script is designed for Fedora. Exiting."
    exit 1
fi

if [[ $EUID -eq 0 ]]; then
    error "Do not run as root. The script will use sudo when needed."
    exit 1
fi

# --- Install packages ---
PACKAGES=(solaar piper)
missing=()
for pkg in "${PACKAGES[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
        missing+=("$pkg")
    fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
    info "Installing ${missing[*]}..."
    sudo dnf install -y "${missing[@]}"
else
    skip "All packages installed"
fi

# --- Remove OpenRGB if present (replaced by g915-led) ---
if rpm -q openrgb &>/dev/null; then
    info "Removing OpenRGB (replaced by g915-led)..."
    sudo dnf remove -y openrgb
fi

# --- Remove old OpenRGB artifacts ---
OLD_SLEEP_HOOK="/usr/lib/systemd/system-sleep/openrgb-resume.sh"
if [[ -f "$OLD_SLEEP_HOOK" ]]; then
    info "Removing old OpenRGB sleep hook..."
    sudo rm -f "$OLD_SLEEP_HOOK"
fi

OLD_SERVICE="$HOME/.config/systemd/user/openrgb.service"
if [[ -f "$OLD_SERVICE" ]]; then
    systemctl --user disable --now openrgb.service 2>/dev/null || true
    rm -f "$OLD_SERVICE"
    systemctl --user daemon-reload
    info "Removed old OpenRGB systemd service."
fi

# --- Solaar autostart ---
SOLAAR_DESKTOP="$HOME/.config/autostart/solaar.desktop"
if [[ ! -f "$SOLAAR_DESKTOP" ]]; then
    mkdir -p "$(dirname "$SOLAAR_DESKTOP")"
    cat > "$SOLAAR_DESKTOP" <<'EOF'
[Desktop Entry]
Name=Solaar
Comment=Logitech device manager
Exec=solaar --window=hide
Terminal=false
Type=Application
Icon=solaar
Categories=Utility;
X-GNOME-Autostart-enabled=true
EOF
    info "Added Solaar to autostart."
else
    skip "Solaar autostart"
fi

# --- G915 TKL udev rule for lighting persistence ---
UDEV_RULE="/etc/udev/rules.d/99-g915-led.rules"
UDEV_SOURCE="$SCRIPT_DIR/99-g915-led.rules"

if [[ ! -f "$UDEV_SOURCE" ]]; then
    error "Missing $UDEV_SOURCE"
    exit 1
fi

if [[ -L "$UDEV_RULE" ]] && [[ "$(readlink "$UDEV_RULE")" == "$UDEV_SOURCE" ]]; then
    skip "G915 udev rule"
else
    sudo ln -sf "$UDEV_SOURCE" "$UDEV_RULE"
    sudo udevadm control --reload-rules
    info "Installed G915 udev rule."
fi

# --- G915 TKL onboard profile (flash) ---
info "Writing onboard profile to G915 TKL flash (all 3 slots)..."
python3 "$SCRIPT_DIR/g915-profile-write.py" 2>/dev/null && \
    info "Onboard profiles written (static blue + yellow logo)." || \
    warn "Could not write onboard profiles (keyboard may not be connected)."

# --- Apply per-key lighting now ---
info "Applying per-key lighting..."
"$SCRIPT_DIR/g915-resume.sh" post 2>/dev/null && \
    info "Per-key lighting applied." || \
    warn "Could not apply per-key lighting."

# --- Print summary ---
echo ""
info "Setup complete!"
echo ""
echo "  g915-led     - Per-key RGB control for G915 TKL"
echo "                 Run: ~/.config/logitech/g915-led --help"
echo ""
echo "  Lighting     - Blue keys, yellow modifiers/media/logo"
echo "                 Onboard profile: static blue+yellow (survives power loss)"
echo "                 udev rule: re-applies per-key colors on reconnect"
echo ""
echo "  Solaar       - Device manager (battery, pairing)"
echo "                 Starts minimized on login"
echo ""
echo "  Piper        - Mouse config for G PRO X Superlight"
echo "                 (DPI, buttons, polling rate)"
echo ""

#!/usr/bin/env bash
#
# Logitech device setup for Fedora (G915 TKL + G PRO X Superlight)
# Installs: Solaar, OpenRGB, Piper
# Configures: udev rules, systemd sleep hook for persistent backlighting
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

# Write a file only if its content differs (or it doesn't exist).
# Usage: write_if_changed DEST_PATH CONTENT
# For root-owned files, pass DEST_PATH starting with / and it will use sudo.
write_if_changed() {
    local dest="$1"
    local content="$2"
    local needs_sudo=false
    local dest_dir
    dest_dir="$(dirname "$dest")"

    # Determine if we need sudo (file outside $HOME)
    if [[ "$dest" != "$HOME"* ]]; then
        needs_sudo=true
    fi

    # Check if file already has the exact content
    if [[ -f "$dest" ]]; then
        local existing
        if $needs_sudo; then
            existing="$(sudo cat "$dest")"
        else
            existing="$(cat "$dest")"
        fi
        if [[ "$existing" == "$content" ]]; then
            return 1 # signal: no change
        fi
    fi

    # Ensure directory exists
    if $needs_sudo; then
        sudo mkdir -p "$dest_dir"
    else
        mkdir -p "$dest_dir"
    fi

    # Write the file
    if $needs_sudo; then
        echo "$content" | sudo tee "$dest" > /dev/null
    else
        echo "$content" > "$dest"
    fi
    return 0 # signal: changed
}

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
PACKAGES=(solaar openrgb openrgb-udev-rules piper)
missing=()
for pkg in "${PACKAGES[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
        missing+=("$pkg")
    fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
    info "Installing ${missing[*]}..."
    sudo dnf install -y "${missing[@]}"

    # Only reload udev after a fresh openrgb-udev-rules install
    if [[ " ${missing[*]} " == *" openrgb-udev-rules "* ]]; then
        info "Reloading udev rules..."
        sudo udevadm control --reload-rules
        sudo udevadm trigger
    fi
else
    skip "All packages installed"
fi

# --- Solaar autostart ---
SOLAAR_DESKTOP='[Desktop Entry]
Name=Solaar
Comment=Logitech device manager
Exec=solaar --window=hide
Terminal=false
Type=Application
Icon=solaar
Categories=Utility;
X-GNOME-Autostart-enabled=true'

if write_if_changed "$HOME/.config/autostart/solaar.desktop" "$SOLAAR_DESKTOP"; then
    info "Added Solaar to autostart."
else
    skip "Solaar autostart"
fi

# --- OpenRGB systemd user service ---
OPENRGB_SERVICE='[Unit]
Description=OpenRGB daemon
After=graphical-session.target

[Service]
ExecStart=/usr/bin/openrgb --server
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target'

service_changed=false
if write_if_changed "$HOME/.config/systemd/user/openrgb.service" "$OPENRGB_SERVICE"; then
    info "Wrote OpenRGB systemd user service."
    service_changed=true
else
    skip "OpenRGB systemd service file"
fi

if $service_changed; then
    systemctl --user daemon-reload
fi

if ! systemctl --user is-enabled openrgb.service &>/dev/null; then
    systemctl --user enable openrgb.service
    info "Enabled OpenRGB service."
else
    skip "OpenRGB service already enabled"
fi

if ! systemctl --user is-active openrgb.service &>/dev/null; then
    systemctl --user start openrgb.service || warn "OpenRGB service failed to start (will work after relogin)"
    info "Started OpenRGB service."
elif $service_changed; then
    systemctl --user restart openrgb.service || warn "OpenRGB service failed to restart"
    info "Restarted OpenRGB service (config changed)."
else
    skip "OpenRGB service already running"
fi

# --- Sleep/resume hook to re-apply OpenRGB profile ---
SLEEP_HOOK='#!/usr/bin/env bash
# Re-apply OpenRGB profile after resume from sleep
# Logitech G915 TKL reverts to rainbow mode after suspend

case "$1" in
    post)
        # Give devices time to re-enumerate after wake
        sleep 3
        # Run as the desktop user
        DESKTOP_USER=$(logname 2>/dev/null || who | awk '\''NR==1{print $1}'\'')
        if [[ -n "$DESKTOP_USER" ]]; then
            PROFILE_DIR="/home/${DESKTOP_USER}/.config/OpenRGB"
            if [[ -d "$PROFILE_DIR" ]]; then
                if [[ -f "$PROFILE_DIR/default.orp" ]]; then
                    su - "$DESKTOP_USER" -c "openrgb --profile default" &
                else
                    FIRST_PROFILE=$(find "$PROFILE_DIR" -maxdepth 1 -name "*.orp" -print -quit 2>/dev/null)
                    if [[ -n "$FIRST_PROFILE" ]]; then
                        su - "$DESKTOP_USER" -c "openrgb --profile \"$FIRST_PROFILE\"" &
                    fi
                fi
            fi
        fi
        ;;
esac'

SLEEP_HOOK_PATH="/usr/lib/systemd/system-sleep/openrgb-resume.sh"

if write_if_changed "$SLEEP_HOOK_PATH" "$SLEEP_HOOK"; then
    sudo chmod +x "$SLEEP_HOOK_PATH"
    info "Installed sleep/resume hook."
else
    skip "Sleep/resume hook"
fi

# --- Print summary ---
echo ""
info "Setup complete!"
echo ""
echo "  Solaar       - Device manager (battery, pairing, DPI)"
echo "                 Starts minimized on login"
echo "                 Run: solaar"
echo ""
echo "  OpenRGB      - RGB backlighting for G915 TKL"
echo "                 Running as systemd user service"
echo "                 Run: openrgb"
echo ""
echo "  Piper        - Mouse config for G PRO X Superlight"
echo "                 (DPI, buttons, polling rate)"
echo "                 Run: piper"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Open OpenRGB, set your preferred lighting, and save as 'default' profile"
echo "     (File > Save Profile > name it 'default')"
echo "     This profile auto-applies after sleep/resume."
echo ""
echo "  2. Open Solaar to verify both devices are detected."
echo ""
echo "  3. Open Piper to configure your Superlight DPI/buttons."
echo ""
echo "  4. If OpenRGB doesn't detect the G915 TKL, try replugging the USB cable."
echo ""

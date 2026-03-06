#!/bin/bash
# setup-gaming.sh — Install Steam + gaming compatibility stack on Fedora
# Run: bash ~/scripts/setup-gaming.sh
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
    echo "Error: Do not run with sudo. It will call sudo only when needed."
    exit 1
fi

echo "=== Gaming Setup for Fedora ==="

# ─── 1. RPM Fusion ──────────────────────────────────────────────
echo "[1/6] Checking RPM Fusion ..."
if rpm -q rpmfusion-free-release rpmfusion-nonfree-release &>/dev/null; then
    echo "    Already enabled."
else
    echo "    Enabling RPM Fusion ..."
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
fi

# ─── 2. Steam + core gaming tools ───────────────────────────────
echo "[2/6] Installing Steam, gamemode, mangohud, gamescope ..."
PKGS=(
    steam
    gamemode
    mangohud
    gamescope
)

MISSING=()
for pkg in "${PKGS[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
        MISSING+=("$pkg")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "    Installing: ${MISSING[*]}"
    sudo dnf install -y "${MISSING[@]}"
else
    echo "    All already installed."
fi

# ─── 3. 32-bit libraries + Vulkan ───────────────────────────────
echo "[3/6] Installing 32-bit and Vulkan support ..."
LIB_PKGS=(
    vulkan-loader
    vulkan-loader.i686
    vulkan-tools
    glibc.i686
    mesa-libGL.i686
    mesa-libGLU.i686
    alsa-lib.i686
    libXrandr.i686
    libXcursor.i686
    freetype.i686
    fontconfig.i686
)

MISSING_LIBS=()
for pkg in "${LIB_PKGS[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
        MISSING_LIBS+=("$pkg")
    fi
done

if [ ${#MISSING_LIBS[@]} -gt 0 ]; then
    echo "    Installing: ${MISSING_LIBS[*]}"
    sudo dnf install -y "${MISSING_LIBS[@]}"
else
    echo "    All already installed."
fi

# ─── 4. Multimedia codecs (game cutscenes) ──────────────────────
echo "[4/6] Installing multimedia codecs ..."
CODEC_PKGS=(
    gstreamer1-plugins-bad-free
    gstreamer1-plugins-good
    gstreamer1-plugins-ugly
    gstreamer1-plugin-libav
)

MISSING_CODECS=()
for pkg in "${CODEC_PKGS[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
        MISSING_CODECS+=("$pkg")
    fi
done

if [ ${#MISSING_CODECS[@]} -gt 0 ]; then
    echo "    Installing: ${MISSING_CODECS[*]}"
    sudo dnf install -y "${MISSING_CODECS[@]}"
else
    echo "    All already installed."
fi

# ─── 5. ProtonUp-Qt (manage Proton/GE-Proton versions) ─────────
echo "[5/6] Installing ProtonUp-Qt ..."
if flatpak list --app 2>/dev/null | grep -q net.davidotek.pupgui2; then
    echo "    Already installed."
else
    flatpak install -y flathub net.davidotek.pupgui2
fi

# ─── 6. Enable gamemode service ─────────────────────────────────
echo "[6/6] Enabling gamemode ..."
if systemctl --user is-active gamemoded.service &>/dev/null; then
    echo "    Already running."
else
    systemctl --user enable --now gamemoded.service
    echo "    Gamemode enabled."
fi

# ─── Sway window rule for Steam ─────────────────────────────────
SWAY_CFG="$HOME/.config/sway/config"
if ! grep -q 'class="Steam".*G' "$SWAY_CFG" 2>/dev/null; then
    echo ""
    echo "Adding Steam workspace rule to sway config ..."
    # Add gaming workspace assignment (reuses existing workspace assignments area)
    sed -i '/assign \[class="1Password"\] L/a\assign [class="Steam"] 5' "$SWAY_CFG"
    # Float Steam popups (friends, chat, small windows)
    sed -i '/for_window.*Picture-in-Picture.*inhibit_idle/a\for_window [class="Steam" title="^Friends"] floating enable\nfor_window [class="Steam" title="^Steam - News"] floating enable' "$SWAY_CFG"
fi

echo ""
echo "=== Gaming setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Launch Steam and log in"
echo "  2. Settings > Compatibility > Enable Steam Play for all titles"
echo "  3. Select 'Proton Experimental' as the default"
echo "  4. Open ProtonUp-Qt to install GE-Proton for games that need it"
echo ""
echo "Launch options for best performance:"
echo "  gamemoderun mangohud %command%"
echo ""
echo "Check game compatibility at: https://www.protondb.com"

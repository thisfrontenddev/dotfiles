#!/usr/bin/env bash
set -euo pipefail

echo "=== Fedora Driver Installation ==="

# ── RPM Fusion repos (needed for NVIDIA drivers) ──
echo "==> Enabling RPM Fusion repos..."
if ! rpm -q rpmfusion-free-release &>/dev/null; then
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
else
  echo "    RPM Fusion already enabled"
fi

# ── NVIDIA drivers ──
echo "==> Installing NVIDIA drivers..."
if rpm -q akmod-nvidia &>/dev/null; then
  echo "    NVIDIA drivers already installed"
else
  sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
  echo "    Waiting for akmod to build kernel module (this may take a minute)..."
  sudo akmods --force && sudo dracut --force
fi

# ── NVIDIA kernel parameters ──
echo "==> Configuring NVIDIA kernel parameters..."
GRUB_FILE="/etc/default/grub"
NEEDS_UPDATE=false
for param in rd.driver.blacklist=nouveau,nova_core modprobe.blacklist=nouveau,nova_core nvidia-drm.modeset=1 nvidia-drm.fbdev=1; do
  if ! grep -q "$param" "$GRUB_FILE"; then
    NEEDS_UPDATE=true
    break
  fi
done
if [[ "$NEEDS_UPDATE" == true ]]; then
  # Append missing params to GRUB_CMDLINE_LINUX
  CURRENT=$(grep '^GRUB_CMDLINE_LINUX=' "$GRUB_FILE" | sed 's/^GRUB_CMDLINE_LINUX="//' | sed 's/"$//')
  for param in rd.driver.blacklist=nouveau,nova_core modprobe.blacklist=nouveau,nova_core nvidia-drm.modeset=1 nvidia-drm.fbdev=1; do
    if ! echo "$CURRENT" | grep -q "$param"; then
      CURRENT="$CURRENT $param"
    fi
  done
  sudo sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"$CURRENT\"|" "$GRUB_FILE"
  sudo grub2-mkconfig -o /boot/grub2/grub.cfg
  echo "    NVIDIA kernel params configured — reboot required"
else
  echo "    NVIDIA kernel params already set"
fi

# ── NVIDIA modprobe config ──
echo "==> Installing NVIDIA modprobe config..."
MODPROBE_SRC="$HOME/.config/nvidia/nvidia-modeset.conf"
MODPROBE_DST="/etc/modprobe.d/nvidia-modeset.conf"
if [[ -L "$MODPROBE_DST" ]] && [[ "$(readlink -f "$MODPROBE_DST")" == "$MODPROBE_SRC" ]]; then
  echo "    modprobe config already symlinked"
else
  sudo ln -sf "$MODPROBE_SRC" "$MODPROBE_DST"
  echo "    modprobe config symlinked"
fi

# ── NVIDIA udev seat preference ──
echo "==> Installing NVIDIA udev seat rule..."
UDEV_SRC="$HOME/.config/nvidia/61-prefer-nvidia.rules"
UDEV_DST="/etc/udev/rules.d/61-prefer-nvidia.rules"
if [[ -L "$UDEV_DST" ]] && [[ "$(readlink -f "$UDEV_DST")" == "$UDEV_SRC" ]]; then
  echo "    udev seat rule already symlinked"
else
  sudo ln -sf "$UDEV_SRC" "$UDEV_DST"
  sudo udevadm control --reload-rules
  echo "    udev seat rule symlinked and reloaded"
fi

echo ""
echo "=== Fedora driver installation complete! ==="

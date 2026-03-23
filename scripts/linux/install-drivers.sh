#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/lib.sh"

echo "=== Driver Installation ($DISTRO) ==="

if [[ "$DISTRO_FAMILY" == "fedora" ]]; then
  # ── RPM Fusion repos (needed for NVIDIA drivers) ──
  echo "==> Enabling RPM Fusion repos..."
  repo_enable rpmfusion

  # ── NVIDIA drivers ──
  echo "==> Installing NVIDIA drivers..."
  if pkg_check akmod-nvidia; then
    echo "    NVIDIA drivers already installed"
  else
    pkg_install akmod-nvidia xorg-x11-drv-nvidia-cuda
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

elif [[ "$DISTRO_FAMILY" == "arch" ]]; then
  echo "==> Skipping driver installation on Arch (handle manually or via installer)"
  suggest_pkg "nvidia-dkms" "NVIDIA kernel module (DKMS rebuilds on kernel updates)"
  suggest_pkg "nvidia-utils" "NVIDIA userspace utilities"
  suggest_pkg "lib32-nvidia-utils" "32-bit NVIDIA libs (needed for Steam/gaming)"
  suggest_pkg "nvidia-settings" "NVIDIA settings GUI"
fi

# ── Config files (all distros) ──
echo "==> Installing NVIDIA modprobe config..."
MODPROBE_SRC="$HOME/.config/nvidia/nvidia-modeset.conf"
MODPROBE_DST="/etc/modprobe.d/nvidia-modeset.conf"
if [[ -f "$MODPROBE_SRC" ]]; then
  if [[ -L "$MODPROBE_DST" ]] && [[ "$(readlink -f "$MODPROBE_DST")" == "$MODPROBE_SRC" ]]; then
    echo "    modprobe config already symlinked"
  else
    sudo ln -sf "$MODPROBE_SRC" "$MODPROBE_DST"
    echo "    modprobe config symlinked"
  fi
fi

echo "==> Installing NVIDIA udev seat rule..."
UDEV_SRC="$HOME/.config/nvidia/61-prefer-nvidia.rules"
UDEV_DST="/etc/udev/rules.d/61-prefer-nvidia.rules"
if [[ -f "$UDEV_SRC" ]]; then
  if [[ -L "$UDEV_DST" ]] && [[ "$(readlink -f "$UDEV_DST")" == "$UDEV_SRC" ]]; then
    echo "    udev seat rule already symlinked"
  else
    sudo ln -sf "$UDEV_SRC" "$UDEV_DST"
    sudo udevadm control --reload-rules
    echo "    udev seat rule symlinked and reloaded"
  fi
fi

echo ""
echo "=== Driver installation complete! ==="

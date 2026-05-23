#!/usr/bin/env bash
# lib.sh — Cross-distro helper library for Linux setup scripts
# Source this at the top of every script: source "$(dirname "$0")/lib.sh"

# ── Colors ──
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

step() { echo -e "\n${GREEN}[✓] $1${NC}"; }
info() { echo -e "${YELLOW}    → $1${NC}"; }
suggest() { echo -e "${CYAN}    [SUGGESTED] $1 — $2${NC}"; }

# ── Distro detection ──
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  DISTRO="${ID:-unknown}"
else
  echo "Cannot detect distro (/etc/os-release missing). Exiting."
  exit 1
fi

case "$DISTRO" in
  fedora)          DISTRO_FAMILY="fedora" ; PKG_MANAGER="dnf" ;;
  arch|cachyos|endeavouros|manjaro)
                   DISTRO_FAMILY="arch"   ; PKG_MANAGER="pacman" ;;
  ubuntu|debian|pop)
                   DISTRO_FAMILY="debian" ; PKG_MANAGER="apt" ;;
  *)
    # Try ID_LIKE as fallback
    case "${ID_LIKE:-}" in
      *arch*)    DISTRO_FAMILY="arch"   ; PKG_MANAGER="pacman" ;;
      *fedora*)  DISTRO_FAMILY="fedora" ; PKG_MANAGER="dnf" ;;
      *debian*)  DISTRO_FAMILY="debian" ; PKG_MANAGER="apt" ;;
      *)         DISTRO_FAMILY="unknown"; PKG_MANAGER="unknown" ;;
    esac
    ;;
esac

export DISTRO DISTRO_FAMILY PKG_MANAGER

# ── Package name mapping (Fedora → Arch) ──
declare -gA PKG_MAP_ARCH=(
  [fd-find]=fd
  [gcc-c++]=gcc
  [golang]=go
  [ninja-build]=ninja
  [ImageMagick]=imagemagick
  [SwayNotificationCenter]=swaync
  [java-latest-openjdk-devel]=jdk-openjdk
  [python3-gobject]=python-gobject
  [python3-hidapi]=python-hidapi
  [pipewire-utils]=pipewire
  [gstreamer1-plugins-bad-free]=gst-plugins-bad
  [gstreamer1-plugins-good]=gst-plugins-good
  [gstreamer1-plugins-ugly]=gst-plugins-ugly
  [gstreamer1-plugin-libav]=gst-libav
  [vulkan-loader]=vulkan-icd-loader
  [vulkan-loader.i686]=lib32-vulkan-icd-loader
  [glibc.i686]=lib32-glibc
  [mesa-libGL.i686]=lib32-mesa
  [mesa-libGLU.i686]=lib32-glu
  [alsa-lib.i686]=lib32-alsa-lib
  [libXrandr.i686]=lib32-libxrandr
  [libXcursor.i686]=lib32-libxcursor
  [freetype.i686]=lib32-freetype2
  [fontconfig.i686]=lib32-fontconfig
)

# Packages that don't exist on Arch (skipped silently)
declare -gA PKG_SKIP_ARCH=(
  [sway-systemd]=1
)

# Packages that are AUR-only on Arch (suggested instead of installed)
declare -gA PKG_AUR_ARCH=(
  [satty]="Screenshot annotation tool"
)

# ── pkg_map: translate a package name for the current distro ──
pkg_map() {
  local pkg="$1"
  if [[ "$DISTRO_FAMILY" == "arch" && -n "${PKG_MAP_ARCH[$pkg]+x}" ]]; then
    echo "${PKG_MAP_ARCH[$pkg]}"
  else
    echo "$pkg"
  fi
}

# ── pkg_install: install packages via the detected package manager ──
pkg_install() {
  local mapped=() pkg
  for pkg in "$@"; do
    # Skip packages that don't exist on this distro
    if [[ "$DISTRO_FAMILY" == "arch" && -n "${PKG_SKIP_ARCH[$pkg]+x}" ]]; then
      info "Skipping $pkg (not available on Arch)"
      continue
    fi
    # Suggest AUR packages instead of installing
    if [[ "$DISTRO_FAMILY" == "arch" && -n "${PKG_AUR_ARCH[$pkg]+x}" ]]; then
      suggest "$pkg" "${PKG_AUR_ARCH[$pkg]} (install from AUR)"
      continue
    fi
    mapped+=("$(pkg_map "$pkg")")
  done

  [[ ${#mapped[@]} -eq 0 ]] && return 0

  case "$DISTRO_FAMILY" in
    fedora) sudo dnf install -y --skip-unavailable "${mapped[@]}" ;;
    arch)   sudo pacman -S --needed --noconfirm "${mapped[@]}" ;;
    debian) sudo apt install -y "${mapped[@]}" ;;
    *)      echo "ERROR: Unknown package manager for $DISTRO_FAMILY"; return 1 ;;
  esac
}

# ── pkg_check: check if a package is installed ──
pkg_check() {
  local pkg="$(pkg_map "$1")"
  case "$DISTRO_FAMILY" in
    fedora) rpm -q "$pkg" &>/dev/null ;;
    arch)   pacman -Qi "$pkg" &>/dev/null ;;
    debian) dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" ;;
    *)      return 1 ;;
  esac
}

# ── suggest_pkg: log a package recommendation without installing ──
suggest_pkg() {
  suggest "$1" "$2"
}

# ── repo_enable: enable a third-party repo ──
repo_enable() {
  local repo_type="$1"; shift
  case "$DISTRO_FAMILY" in
    fedora)
      case "$repo_type" in
        rpmfusion)
          if ! rpm -q rpmfusion-free-release &>/dev/null; then
            sudo dnf install -y \
              "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
              "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
          else
            info "RPM Fusion already enabled"
          fi
          ;;
        copr)
          sudo dnf copr enable -y "$@"
          ;;
      esac
      ;;
    arch)
      info "Skipping repo_enable ($repo_type) — not applicable on Arch"
      ;;
  esac
}

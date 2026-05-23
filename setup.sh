#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")/scripts" && pwd)"

case "$(uname -s)" in
  Darwin)
    echo "=== macOS Setup ==="
    bash "$SCRIPTS_DIR/macos/bootstrap.sh"
    ;;
  Linux)
    if [[ ! -r /etc/os-release ]]; then
      echo "Cannot detect Linux distro: /etc/os-release missing"
      exit 1
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}${ID_LIKE:-}" in
      *arch*)   DISTRO_DIR="arch" ;;
      *fedora*) DISTRO_DIR="fedora" ;;
      *)        echo "Unsupported Linux distro: ${ID:-unknown}"; exit 1 ;;
    esac
    BOOTSTRAP="$SCRIPTS_DIR/$DISTRO_DIR/bootstrap.sh"
    if [[ ! -f "$BOOTSTRAP" ]]; then
      echo "No bootstrap script at $BOOTSTRAP"
      echo "Create one (or check /etc/os-release detection) before running setup.sh on this distro."
      exit 1
    fi
    echo "=== Linux Setup (${ID}) ==="
    bash "$BOOTSTRAP"
    ;;
  *)
    echo "Unsupported OS: $(uname -s)"
    exit 1
    ;;
esac

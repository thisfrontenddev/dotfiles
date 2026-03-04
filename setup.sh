#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")/scripts" && pwd)"

case "$(uname -s)" in
  Darwin)
    echo "=== macOS Setup ==="
    bash "$SCRIPTS_DIR/bootstrap.sh"
    ;;
  Linux)
    echo "=== Linux Setup ==="
    bash "$SCRIPTS_DIR/bootstrap-linux.sh"
    ;;
  *)
    echo "Unsupported OS: $(uname -s)"
    exit 1
    ;;
esac

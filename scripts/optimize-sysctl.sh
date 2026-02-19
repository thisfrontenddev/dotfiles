#!/usr/bin/env bash
set -euo pipefail

echo "==> Optimizing kernel limits..."

# Note: kern.maxproc (4000) and kern.maxprocperuid (2666) are hardcoded
# on Apple Silicon and cannot be raised.

# Show current values
echo "  Current values:"
sysctl kern.maxfiles kern.maxfilesperproc | sed 's/^/    /'

# Raise file descriptor limits
sudo sysctl kern.maxfiles=524288
sudo sysctl kern.maxfilesperproc=262144

# Persist across reboots via /etc/sysctl.conf
SYSCTL_CONF="/etc/sysctl.conf"
SYSCTL_CONTENT="kern.maxfiles=524288
kern.maxfilesperproc=262144"

if [[ -f "$SYSCTL_CONF" ]]; then
  local_tmp=$(mktemp)
  # Remove any existing kern.max* lines, then append ours
  grep -v '^kern\.max' "$SYSCTL_CONF" > "$local_tmp" 2>/dev/null || true
  echo "$SYSCTL_CONTENT" >> "$local_tmp"
  sudo cp "$local_tmp" "$SYSCTL_CONF"
  rm "$local_tmp"
else
  echo "$SYSCTL_CONTENT" | sudo tee "$SYSCTL_CONF" > /dev/null
fi

echo ""
echo "  New values:"
sysctl kern.maxfiles kern.maxfilesperproc | sed 's/^/    /'

echo "==> Kernel limits optimization complete (persisted in $SYSCTL_CONF)."

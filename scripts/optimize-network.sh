#!/usr/bin/env bash
set -euo pipefail

echo "==> Optimizing network settings..."

# --- Use Cloudflare DNS (fast, privacy-focused) ---
# Get the active network service
ACTIVE_SERVICE=$(networksetup -listnetworkserviceorder | grep -B1 "$(route get default 2>/dev/null | awk '/interface:/{print $2}')" | head -1 | sed 's/^([0-9]*) //' | sed 's/^ *//' || echo "Wi-Fi")

if [[ -n "$ACTIVE_SERVICE" ]]; then
  echo "==> Setting DNS for: $ACTIVE_SERVICE"
  networksetup -setdnsservers "$ACTIVE_SERVICE" 1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001
  echo "==> DNS set to Cloudflare (1.1.1.1)"
else
  echo "==> Could not detect active service, setting Wi-Fi DNS"
  networksetup -setdnsservers "Wi-Fi" 1.1.1.1 1.0.0.1
fi

# --- Flush DNS cache ---
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
echo "==> DNS cache flushed"

echo "==> Network optimization complete."

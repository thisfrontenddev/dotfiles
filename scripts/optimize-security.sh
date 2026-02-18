#!/usr/bin/env bash
set -euo pipefail

echo "==> Applying security hardening..."

# --- Enable macOS firewall ---
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
echo "  Firewall: enabled"

# --- Enable stealth mode (don't respond to pings) ---
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
echo "  Stealth mode: enabled"

# --- Disable remote Apple Events ---
sudo systemsetup -setremoteappleevents off 2>/dev/null || true
echo "  Remote Apple Events: disabled"

# --- Disable remote login (SSH) unless needed ---
# Uncomment if you don't need SSH access to this machine:
# sudo systemsetup -setremotelogin off
# echo "  Remote login (SSH): disabled"

# --- Require password immediately after sleep/screensaver ---
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
echo "  Lock on sleep: immediate"

# --- Disable AirDrop by default ---
# defaults write com.apple.NetworkBrowser DisableAirDrop -bool true
# echo "  AirDrop: disabled"

echo "==> Security hardening complete."

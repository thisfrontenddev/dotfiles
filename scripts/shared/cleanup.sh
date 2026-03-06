#!/usr/bin/env bash
set -euo pipefail

echo "=== Mac Cleanup Script ==="
echo ""

# Track space before
BEFORE=$(df -h / | awk 'NR==2{print $4}')
echo "Disk space available before: $BEFORE"
echo ""

# --- Homebrew ---
echo "==> Cleaning Homebrew cache..."
brew cleanup --prune=7 -s 2>/dev/null
brew autoremove 2>/dev/null
echo ""

# --- Xcode ---
if [[ -d "$HOME/Library/Developer/Xcode/DerivedData" ]]; then
  echo "==> Cleaning Xcode derived data..."
  rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/*
fi

if [[ -d "$HOME/Library/Developer/Xcode/Archives" ]]; then
  echo "==> Cleaning Xcode archives..."
  rm -rf "$HOME/Library/Developer/Xcode/Archives"/*
fi

# --- npm / pnpm ---
echo "==> Cleaning npm cache..."
npm cache clean --force 2>/dev/null || true

echo "==> Cleaning pnpm store..."
pnpm store prune 2>/dev/null || true

# --- Docker / OrbStack ---
if command -v docker &>/dev/null; then
  echo "==> Cleaning Docker unused resources..."
  docker system prune -f 2>/dev/null || true
fi

# --- System caches (safe ones) ---
echo "==> Cleaning user caches..."
rm -rf "$HOME/Library/Caches/com.apple.dt.Xcode" 2>/dev/null || true
rm -rf "$HOME/Library/Caches/com.google.SoftwareUpdate" 2>/dev/null || true
rm -rf "$HOME/Library/Caches/Google" 2>/dev/null || true

# --- Logs ---
echo "==> Cleaning old logs..."
sudo rm -rf /private/var/log/asl/*.asl 2>/dev/null || true
rm -rf "$HOME/Library/Logs/DiagnosticReports"/* 2>/dev/null || true

# --- .DS_Store files ---
echo "==> Removing .DS_Store files from home..."
find "$HOME" -maxdepth 4 -name ".DS_Store" -delete 2>/dev/null || true

# --- Trash ---
echo "==> Emptying Trash..."
rm -rf "$HOME/.Trash"/* 2>/dev/null || true

# --- Summary ---
echo ""
AFTER=$(df -h / | awk 'NR==2{print $4}')
echo "Disk space available after: $AFTER"
echo "=== Cleanup complete ==="

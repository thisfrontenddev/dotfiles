#!/usr/bin/env bash
set -euo pipefail

echo "==> Optimizing Spotlight indexing..."

# Disable Spotlight indexing for development directories
# These are added to the Spotlight privacy list (excluded from indexing)
EXCLUDE_DIRS=(
  "$HOME/Library/Caches"
  "$HOME/.cargo"
  "$HOME/.local"
  "$HOME/.cache"
  "$HOME/.npm"
  "$HOME/.pnpm-store"
  "$HOME/Library/pnpm"
  "$HOME/OrbStack"
)

for dir in "${EXCLUDE_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    sudo mdutil -i off "$dir" 2>/dev/null || true
    echo "  Excluded: $dir"
  fi
done

# Note: node_modules and .git are better handled by adding to Spotlight
# privacy list via System Settings > Spotlight > Search Privacy
echo ""
echo "==> MANUAL: Add ~/work and other project roots to Spotlight Privacy list"
echo "   System Settings > Spotlight > Search Privacy > Add directories"
echo "   (Raycast handles project search better than Spotlight anyway)"

echo "==> Spotlight optimization complete."

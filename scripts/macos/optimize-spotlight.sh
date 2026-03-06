#!/usr/bin/env bash
set -euo pipefail

echo "==> Optimizing Spotlight indexing..."

# Disable Spotlight indexing for development directories
# These are added to the Spotlight privacy list (excluded from indexing)
EXCLUDE_DIRS=(
  "$HOME/Projects"
  "$HOME/work"
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

# ============================================================================
# TIME MACHINE EXCLUSIONS
# ============================================================================

echo "==> Excluding dev artifacts from Time Machine..."

# Exclude node_modules from all project directories
for dir in "$HOME"/Projects/*/node_modules "$HOME"/work/*/node_modules; do
  if [[ -d "$dir" ]]; then
    tmutil addexclusion "$dir" 2>/dev/null || true
    echo "  Excluded from TM: $dir"
  fi
done

# Exclude caches
if [[ -d "$HOME/.cache" ]]; then
  tmutil addexclusion "$HOME/.cache" 2>/dev/null || true
  echo "  Excluded from TM: ~/.cache"
fi

echo "==> Spotlight & Time Machine optimization complete."

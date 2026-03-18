#!/usr/bin/env bash
set -euo pipefail

# --- Variables ---
VAULT_DIR="$HOME/vaults/brain"
PLUGIN_DIR="$VAULT_DIR/.obsidian/plugins/obsidian-git"
REPO_URL="git@github.com:thisfrontenddev/brain.git"

# --- OS Detection ---
OS="$(uname -s)"
case "$OS" in
    Linux|Darwin) ;;
    *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

echo "Detected OS: $OS"

# --- Step 1: Vault directory and git init ---
if [ -d "$VAULT_DIR/.git" ]; then
    CURRENT_REMOTE=$(git -C "$VAULT_DIR" remote get-url origin 2>/dev/null || true)
    if [ "$CURRENT_REMOTE" = "$REPO_URL" ]; then
        echo "Vault already set up at $VAULT_DIR — skipping init"
    else
        echo "Vault exists but remote differs. Updating remote to $REPO_URL"
        git -C "$VAULT_DIR" remote set-url origin "$REPO_URL"
    fi
else
    mkdir -p "$VAULT_DIR"
    git -C "$VAULT_DIR" init
    git -C "$VAULT_DIR" remote add origin "$REPO_URL"
    echo "Initialized git repo at $VAULT_DIR"
fi

# Try to pull existing content
if git -C "$VAULT_DIR" ls-remote origin main &>/dev/null; then
    echo "Pulling existing content from remote..."
    git -C "$VAULT_DIR" fetch origin main 2>/dev/null || true
    git -C "$VAULT_DIR" checkout main 2>/dev/null || git -C "$VAULT_DIR" checkout -b main 2>/dev/null || true
    git -C "$VAULT_DIR" pull origin main --rebase 2>/dev/null || true
else
    echo "Remote appears empty — will push initial content"
    git -C "$VAULT_DIR" checkout -b main 2>/dev/null || true
fi

# --- Step 2: Create .gitignore ---
GITIGNORE="$VAULT_DIR/.gitignore"
if [ ! -f "$GITIGNORE" ]; then
    cat > "$GITIGNORE" << 'GITIGNORE_EOF'
# Obsidian workspace (device-specific, not synced)
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/workspaces.json

# OS junk
.DS_Store
Thumbs.db

# Obsidian cache
.obsidian/cache
.trash/
GITIGNORE_EOF
    echo "Created .gitignore"
else
    echo ".gitignore already exists — skipping"
fi

# --- Step 3: Install obsidian-git plugin ---
mkdir -p "$PLUGIN_DIR"

echo "Fetching latest obsidian-git release..."
LATEST=$(curl -sf https://api.github.com/repos/Vinzent03/obsidian-git/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST" ]; then
    echo "Error: Failed to fetch latest release tag" >&2
    exit 1
fi

echo "Downloading obsidian-git $LATEST..."
BASE_URL="https://github.com/Vinzent03/obsidian-git/releases/download/$LATEST"

for FILE in main.js manifest.json styles.css; do
    curl -sfL "$BASE_URL/$FILE" -o "$PLUGIN_DIR/$FILE"
    if [ ! -s "$PLUGIN_DIR/$FILE" ]; then
        echo "Error: Failed to download $FILE" >&2
        exit 1
    fi
done

echo "Plugin downloaded successfully"

# --- Step 4: Write plugin config ---
DATA_JSON="$PLUGIN_DIR/data.json"
if [ ! -f "$DATA_JSON" ]; then
    cat > "$DATA_JSON" << 'DATA_EOF'
{
  "autoSaveInterval": 1,
  "autoBackupAfterFileChange": true,
  "autoPullOnBoot": true,
  "autoPullInterval": 5,
  "disablePush": false,
  "pullBeforePush": true,
  "disablePopups": false,
  "disablePopupsForNoChanges": true,
  "autoCommitMessage": "vault backup: {{date}}",
  "commitDateFormat": "YYYY-MM-DD HH:mm:ss",
  "syncMethod": "merge",
  "showStatusBar": true,
  "changedFilesInStatusBar": true,
  "showBranchStatusBar": true
}
DATA_EOF
    echo "Created plugin config (data.json)"
else
    echo "data.json already exists — skipping"
fi

# --- Step 5: Enable plugin in Obsidian config ---
mkdir -p "$VAULT_DIR/.obsidian"
COMMUNITY_PLUGINS="$VAULT_DIR/.obsidian/community-plugins.json"

if [ ! -f "$COMMUNITY_PLUGINS" ]; then
    echo '["obsidian-git"]' > "$COMMUNITY_PLUGINS"
    echo "Created community-plugins.json"
elif ! grep -q '"obsidian-git"' "$COMMUNITY_PLUGINS"; then
    # Insert "obsidian-git" before the closing bracket
    sed -i.bak 's/\]/"obsidian-git"\]/' "$COMMUNITY_PLUGINS"
    # Add comma after previous entry if needed
    sed -i.bak 's/"\([^"]*\)""obsidian-git"/"\1","obsidian-git"/' "$COMMUNITY_PLUGINS"
    rm -f "${COMMUNITY_PLUGINS}.bak"
    echo "Added obsidian-git to community-plugins.json"
else
    echo "obsidian-git already enabled — skipping"
fi

# --- Step 6: Initial commit and push ---
cd "$VAULT_DIR"
git add -A

if ! git diff --cached --quiet; then
    git commit -m "initial vault setup with obsidian-git plugin"
    git branch -M main
    git push -u origin main
    echo "Initial commit pushed to remote"
else
    echo "No changes to commit"
fi

# --- Step 7: Check if Obsidian is running ---
if pgrep -x obsidian &>/dev/null || pgrep -x Obsidian &>/dev/null; then
    echo ""
    echo "⚠  Obsidian is running — restart it to pick up the new plugin"
fi

# --- Summary ---
echo ""
echo "Obsidian Git Sync setup complete!"
echo ""
echo "  Vault:   ~/vaults/brain"
echo "  Remote:  $REPO_URL"
echo "  Plugin:  obsidian-git (auto-commit 1min debounce, auto-pull 5min)"
echo ""
echo "  Next steps:"
echo "  - Open Obsidian and select ~/vaults/brain as your vault"
echo "  - The obsidian-git plugin is pre-configured and ready"
echo "  - For iOS setup, see: docs/obsidian-ios-setup.md"

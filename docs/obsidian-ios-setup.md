# Obsidian iOS Setup (Git Sync)

Sync your `brain` vault on iOS using Working Copy and Shortcuts.

## 1. App Installation

1. Install **Working Copy** from the App Store (free for pull, $22 one-time for push)
2. Install **Obsidian** from the App Store
3. Open Working Copy → clone `git@github.com:thisfrontenddev/brain.git`

## 2. Link Vault to Obsidian

1. Open Obsidian on iOS
2. Tap "Open folder as vault"
3. Navigate to Working Copy's file provider → select the `brain` repo
4. The vault opens with all notes synced

## 3. Auto Pull on Open (Shortcut)

Create an iOS Shortcut automation:

- **Trigger:** "When Obsidian is opened"
- **Actions:**
  1. Working Copy → "Pull Repository" → select `brain`
- **Settings:** Run immediately (no confirmation)

This ensures you always start with the latest notes.

## 4. Auto Commit + Push on Close (Shortcut)

Create an iOS Shortcut automation:

- **Trigger:** "When Obsidian is closed"
- **Actions:**
  1. Working Copy → "Stage for Commit" → path: `*`, repository: `brain`
  2. Working Copy → "Commit Repository" → repository: `brain`, message: `vault backup: ios`
  3. Working Copy → "Push Repository" → repository: `brain`
- **Settings:** Run immediately (no confirmation)

This saves and pushes your changes whenever you leave Obsidian.

## 5. Conflict Handling

- If both devices edit the same file simultaneously, git merge handles it automatically
- In rare conflict cases, Working Copy shows conflict markers for manual resolution
- The auto-pull shortcut minimizes conflicts by pulling before you start editing

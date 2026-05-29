# cybrdots Layering — Implementation Plan (thin layering)

> **Superseded the CLI plan on 2026-05-30.** See the spec's "Revision 2026-05-30" note. This is the thin-layering version: one small script + hand-written loaders, no CLI.

**Goal:** Layer the user's overrides on top of upstream `cybrcore` components (read live from a gitignored cache via loader files), with a single ~25-line helper that clones + relinks. Migrate `hypr` and `waybar` as the pilot.

**Mechanism (unchanged from spec):** Per app, the entry file in `~/.config` is a small loader the user owns that includes the cached upstream entry first, then the user's override last (override wins). Upstream's sibling files are symlinked from the cache into the target dir so upstream's internal `~/.config/...` references resolve. Cache lives at `~/.local/share/cybrdots/` (gitignored). Updates are plain `git pull` in the cache.

---

## Step 0: Clean up the CLI scaffolding

Remove the abandoned `cybr` CLI (Tasks 1–5 of the old plan); add the one script.

- [ ] Add `scripts/shared/cybr-sync` (content below), `chmod +x`.
- [ ] `git rm` the CLI: `scripts/shared/cybr/{cybr,lib.sh,components.toml,test/test_cybr.sh}`.
- [ ] Commit (signed): `chore(cybr): replace CLI with thin cybr-sync layering script`.

`scripts/shared/cybr-sync`:
```bash
#!/usr/bin/env bash
# cybr-sync — clone (if missing) + relink cybr theming components into ~/.config.
# Selective install: comment/uncomment the sync lines at the bottom.
# Update a component:  git -C ~/.local/share/cybrdots/<name> pull  &&  cybr-sync
set -euo pipefail
CACHE="${XDG_DATA_HOME:-$HOME/.local/share}/cybrdots"

# repo_url  target(rel to $HOME)  entry_file(your loader owns this; never symlinked)
sync() {
  local repo="$1" target="$HOME/$2" entry="$3"
  local dir="$CACHE/$(basename "$repo" .git)"
  [[ -d "$dir/.git" ]] || git clone --depth=1 "$repo" "$dir"
  mkdir -p "$target"
  shopt -s nullglob
  for f in "$dir"/*; do
    local base; base="$(basename "$f")"
    [[ "$base" == "$entry" || "$base" == README.md || "$base" == LICENSE ]] && continue
    local dest="$target/$base"
    if [[ -L "$dest" ]]; then rm -f "$dest"
    elif [[ -e "$dest" ]]; then mv "$dest" "$dest.pre-cybr.bak"; fi
    ln -sfn "$f" "$dest"
  done
  shopt -u nullglob
}

# --- your components (this list IS your manifest + selective install) ---
sync https://github.com/cybrcore/cybr-hyprland.git .config/hypr   hyprland.conf
sync https://github.com/cybrcore/cybr-waybar.git   .config/waybar config.jsonc
```

## Step 1: Ignore the cache + mirrored symlinks in `~/.cfg`

- [ ] Append to `$HOME/.cfg/info/exclude`:
  ```
  .local/share/cybrdots/
  ```
- [ ] After the pilot, also ensure the mirrored sibling symlinks in `~/.config/hypr` and `~/.config/waybar` are not accidentally tracked (they regenerate from `cybr-sync`). Verify with `git --git-dir=$HOME/.cfg --work-tree=$HOME status` — they should not appear as new tracked content; if any do, do not `git add` them.

## Step 2: Pilot — `hypr` (interactive, with the user watching)

- [ ] Back up: `cp -r ~/.config/hypr ~/.config/hypr.pre-cybr.bak`.
- [ ] Run `bash ~/scripts/shared/cybr-sync` (clones cybr-hyprland, mirrors siblings, backing up your real files to `*.pre-cybr.bak`).
- [ ] Verify the gotcha is resolved: `readlink ~/.config/hypr/theme.conf` → cache path.
- [ ] Write `~/.config/hypr/override.conf` with your genuine deltas (from the backup): NVIDIA/HDR `render { cm_auto_hdr = 2 }` + `debug { damage_tracking = 1 }`, hyprbars block, CYBR border colors, your binds, `source = ~/.config/hypr/monitors.conf`. (See the spec/old-plan Task 7 for the concrete block.)
- [ ] Write the loader `~/.config/hypr/hyprland.conf`:
  ```conf
  # Loader (cybr). Upstream read live from cache; override wins.
  source = ~/.local/share/cybrdots/cybr-hyprland/hyprland.conf
  source = ~/.config/hypr/override.conf
  ```
- [ ] Verify: `hyprctl reload` then check `hyprctl getoption general:col.active_border` (F24848), `debug:damage_tracking` (1), `render:cm_auto_hdr` (2); confirm borders/titlebars/monitors/waybar visually. Roll back if wrong: `rm -rf ~/.config/hypr && mv ~/.config/hypr.pre-cybr.bak ~/.config/hypr`.
- [ ] Untrack now-upstream-owned files: `git --git-dir=$HOME/.cfg --work-tree=$HOME rm --cached .config/hypr/theme.conf .config/hypr/env.conf .config/hypr/input.conf .config/hypr/workspaces.conf .config/hypr/plugins/hyprexpo.conf` (keep: `hyprland.conf` loader, `override.conf`, `monitors.conf`, `monitors.lua`).
- [ ] Commit (signed): loader + override + the removals. Then `rm -rf ~/.config/hypr.pre-cybr.bak`.

## Step 3: Pilot — `waybar` (interactive)

- [ ] Back up: `cp -r ~/.config/waybar ~/.config/waybar.pre-cybr.bak`. Run `cybr-sync`.
- [ ] **Verify waybar include precedence** (the one unverified assumption): does a later `include` override an earlier one? Test with a sentinel in `override.jsonc`; if it does NOT win, the loader must carry overrides as top-level keys instead (top-level beats includes in waybar).
- [ ] Loader `~/.config/waybar/config.jsonc`: `{ "include": [ "~/.local/share/cybrdots/cybr-waybar/config.jsonc", "~/.config/waybar/override.jsonc" ] }`.
- [ ] Your waybar customizations are mostly your own scripts/styles — keep `scripts/`, `svg/`, `launch.sh`, and (if you keep little of upstream's CSS) your own `style.css` tracked as own-files; put genuine config deltas in `override.jsonc`.
- [ ] Verify: `pkill waybar; ~/.config/waybar/launch.sh` — bar renders identically across both monitors. Roll back if wrong.
- [ ] Untrack upstream-owned `modules.jsonc`; commit loader + override + removals (signed). `rm -rf ~/.config/waybar.pre-cybr.bak`.

## Step 4: Cleanup + wire-up

- [ ] Remove the stale `scripts/fedora/install-cybrland.sh` (check for remaining references first).
- [ ] Optionally add to `scripts/arch/bootstrap.sh`: `bash "$HOME/scripts/shared/cybr-sync"` so a fresh machine relinks the components.
- [ ] Commit (signed).

## How it meets the objectives

- **Selective install:** the `sync …` lines at the bottom of `cybr-sync` (add/remove a line per component).
- **Update + my-config-wins:** `git -C <cache>/<comp> pull && cybr-sync`; your override is a separate file, included last, never touched. "What changed upstream" = `git -C <cache>/<comp> log`/`diff`.
- **Remove old manual changes:** the pilot migration extracts your real deltas into `override.*` and lets upstream own the baseline; `~/.cfg` stops tracking the upstream files.

## Notes / deferred

- Other components (kitty, rofi, swaync, btop, fastfetch, starship, fish, …) roll in later by adding a `sync` line + writing their loader/override, same recipe.
- No pinned SHAs (the full-CLI feature we dropped). A fresh machine re-clones latest via `cybr-sync`; if you ever want a pin, add `git -C <dir> checkout <sha>` after the clone for that component.

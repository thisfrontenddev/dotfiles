# cybrdots layering — design

**Date:** 2026-05-29
**Goal:** Consume the `cybrcore` theming components (`cybr-*`) as rolling upstream, layer the user's own overrides on top so they always win, and untangle the user's customizations from the upstream baseline in the `~/.cfg` bare dotfiles repo.

> **Revision 2026-05-30 — pivot to "thin layering."** The original design wrapped the loader/override mechanism in a `cybr` CLI (registry + manifest + 8 subcommands). After building it through Task 5, the reviewer-found gaps were all in that CLI plumbing — accidental complexity for a personal, 1–2 machine setup. We reaffirmed (against upstream `INSTALL.md`, which only copies-and-overwrites with no update/override story) that the **layering itself is necessary**, but the CLI is not. The mechanism is unchanged below; only the packaging changes: a single ~25-line `scripts/shared/cybr-sync` script (clone-if-missing + backup-safe symlink mirroring) replaces the CLI. Loaders + overrides are hand-written once and committed. Updates are plain `git -C <cache>/<comp> pull && cybr-sync`; "what changed" is plain `git log`/`git diff`. The `sync …` lines at the bottom of the script are both the selective-install switch and the committed record of enabled components (no separate manifest/registry). The pilot migration (hypr, waybar) is unchanged in spirit.

## Problem

The user's `~/.cfg` bare repo (→ `thisfrontenddev/dotfiles`) directly tracks `~/.config/*`. Many tracked files are heavily customized descendants of the old `scherrer-txt/cybrland` repo (CYBR-colored hypr `theme.conf`, custom waybar scripts, NVIDIA/HDR workarounds, monitor self-heal). Upstream has since reorganized into the `cybrcore` org: an umbrella `cybrdots` repo that pulls per-app component repos (`cybr-hyprland`, `cybr-waybar`, `cybr-kitty`, …) in as git submodules, plus a shared `cybrcolors` palette.

The user's customizations and the upstream baseline are tangled and indistinguishable in `~/.cfg`. The old puller (`scripts/fedora/install-cybrland.sh`) is a stale, Fedora/Sway-era curl script.

### Wants

1. Choose which components to install (selective).
2. Track upstream updates, but never silently lose local changes — local config has priority (a higher-level override layer).
3. Remove the old manual changes and switch to the new `cybrcore` components.

## Decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Where upstream config lives | **Out-of-tree, gitignored cache** + a committed manifest in `~/.cfg` |
| 2 | Override/priority model | **Native-include layering** (override wins, included last) |
| 3 | How upstream reaches `~/.config` | **Loader files** that read upstream live from the cache |
| 4 | Dependency install | **Tool installs deps**, check-then-install-only-missing |
| 5 | Migration aggressiveness | **Pilot first** (hypr + waybar), then expand |

Rationale: the user prefers native tooling and simplicity over abstraction, keeps repos/docs lean, and is newer to Linux. The loader-from-cache model makes overwrites *structurally impossible* (override is always a separate file that wins), so want #2 dissolves into "review upstream changes before you pull" rather than needing a detection mechanism.

## Architecture

Three layers, one direction of flow:

```
 UPSTREAM (cybrcore)          CACHE (out-of-tree, gitignored)        LIVE
 cybr-hyprland  ──git clone──▶ ~/.local/share/cybrdots/cybr-hyprland ──┐
 cybr-waybar    ──git clone──▶ ~/.local/share/cybrdots/cybr-waybar  ──┤ included by
 cybrcolors     ──git clone──▶ ~/.local/share/cybrdots/cybrcolors   ──┤ loader files
                                                                       ▼
 YOUR REPO (~/.cfg, committed)                                   ~/.config/<app>/
 ├─ manifest          (which components + pinned SHAs)           ├─ <loader>  ──▶ sources cache + override
 ├─ override fragments (your deltas, win last)        ──────────▶├─ <override> (your layer)
 └─ truly-own configs (monitors, NVIDIA, …)           ──────────▶└─ (deployed as today)
```

- **Cache** (`~/.local/share/cybrdots/`): pristine per-component git clones. Never edited. `git pull` here is the update. Gitignored; rebuildable from the manifest. Components are cloned individually (not via the `cybrdots` umbrella + submodules) so selection is per-component.
- **`~/.cfg`** holds only the user's stuff: the manifest, override fragments, and configs with no upstream equivalent. Stays lean; syncs to macOS harmlessly (nothing deploys there).
- **`~/.config`** holds tiny **loader files** the user owns that chain `upstream-from-cache` → `your-override`, with the override included last so it wins.

### Two data files in `~/.cfg`

- **Registry** (tool data, `scripts/shared/cybr/components.toml`): the tool's built-in knowledge of every known component — repo URL, target dir, include style, dependency packages. Data-driven so adding a component is a data edit, not a code change.
- **Manifest** (user state, `~/.config/cybrdots/manifest.toml`): just the components the user enabled + their pinned commit SHAs. Minimal and personal — the reproducibility anchor.

## The `cybr` tool

Lives at `scripts/shared/cybr/cybr`. Detects the package manager at runtime (paru/dnf/apt — same pattern as the existing `waybar/scripts/pkg-updates.sh`), so the layering logic is portable; only the dep-install step is PM-specific.

| Command | Does |
|---|---|
| `cybr list` | Show all known components (registry) + which are enabled |
| `cybr enable <comp>` | Add to manifest, clone into cache, install missing deps, write loader + scaffold an empty override |
| `cybr disable <comp>` | Remove loader, drop from manifest, archive the override |
| `cybr sync` | Reconcile everything to the manifest at pinned SHAs + ensure deps/loaders. The fresh-machine command. Idempotent. |
| `cybr update [comp]` | `git pull` in cache, show the upstream diff, bump the pinned SHA |
| `cybr status` | Enabled components; pinned-vs-upstream; flag components with new upstream commits |
| `cybr diff <comp>` | Show what changed upstream since the pinned SHA |

Dependency install is check-then-install-only-missing, so re-running is cheap.

## Loader mechanics per tool

Each include-capable tool gets a loader that chains *upstream-from-cache* then *your override* (last wins):

| Tool | Loader file | Mechanism |
|---|---|---|
| **hypr** | `hyprland.conf` | `source = <cache>/…` then `source = …/override.conf` |
| **waybar** | `config.jsonc` | `"include": ["<cache>/config.jsonc", "override.jsonc"]`; `style.css` uses `@import` (cache, then override) |
| **kitty** | `kitty.conf` | `include <cache>/kitty.conf` then `include override.conf` |
| **rofi** | `config.rasi` | `@import` cache theme, then override |
| **fish** | *(no loader)* | symlink upstream `conf.d/*` + drop a `zz-override.fish` (sorts last) |
| **starship** & other no-include tools | *(full-file)* | the user's file in `~/.cfg` wins wholesale; tool tracks the upstream version for manual diffing |

### Known gotcha — Hyprland `source` paths

Upstream `cybr-hyprland`'s `hyprland.conf` internally sources its siblings (`theme.conf`, `vars.conf`, etc.). If those use `~/.config/hypr/…` absolute paths, they resolve to the *live* dir, not the cache — breaking the read-from-cache model. During the pilot, inspect upstream's actual `source` paths and adapt the loader accordingly (source each upstream file explicitly, or set a base var). This is the single riskiest unknown, which is why hypr goes first.

## Migration

### Pilot: `hypr` + `waybar`, per component

1. `cybr enable` clones upstream into the cache + installs deps.
2. **Diff** the current live config against upstream to separate "upstream baseline" from "genuine local deltas."
3. Extract local deltas into the **override** fragment:
   - hypr: NVIDIA/HDR `damage_tracking`, hyprbars, CYBR border colors, custom binds.
   - waybar: custom scripts (`gpu-info`, `mediaplayer.py`, self-heal `launch.sh`) + style tweaks.
4. Replace the live file with the **loader**.
5. **Stop tracking** the now-upstream-owned files in `~/.cfg` (`git rm --cached`); commit the loader + override + manifest instead.
6. **Verify** the desktop looks/behaves identically (reload hypr/waybar) before declaring the component done.

Truly-own files (`monitors.conf`, `monitors.lua`, NVIDIA rules, waybar custom scripts) stay tracked in `~/.cfg` exactly as now.

### Bare-repo integration

- Add `~/.local/share/cybrdots/` to the `~/.cfg` ignore so the cache is never committed.
- After each component migrates, `~/.cfg`'s tracked set for that app shrinks to {loader, override, own files} — removing the tangle.
- The manifest + overrides travel with `~/.cfg` to any machine; `cybr sync` rebuilds the cache and re-deploys. macOS never runs `cybr`, so it's inert there.

## Deferred (YAGNI)

Remaining overlapping components (kitty, rofi, swaync, btop, fastfetch, starship, fish, …) roll in **after** the pilot proves out, one or a few at a time, using the same recipe. The old `scripts/fedora/install-cybrland.sh` and any Fedora/Sway-era cybr remnants get removed once their components are migrated or retired.

## Success criteria

- `cybr enable hypr` and `cybr enable waybar` produce a working, visually-identical desktop.
- `~/.cfg` no longer tracks upstream-owned hypr/waybar baseline files — only loaders, overrides, and own files.
- An upstream change is reviewable via `cybr status` / `cybr diff` and applied via `cybr update`, with local overrides surviving untouched.
- A fresh machine can rebuild the full setup from `~/.cfg` + `cybr sync`.

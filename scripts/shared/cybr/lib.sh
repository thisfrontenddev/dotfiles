#!/usr/bin/env bash
# cybr library — sourced by the `cybr` dispatcher and by tests.
# All paths are overridable via env vars so tests can use temp dirs.
set -uo pipefail

: "${CYBR_HOME:=$HOME}"
: "${CYBR_CACHE:=${XDG_DATA_HOME:-$CYBR_HOME/.local/share}/cybrdots}"
: "${CYBR_MANIFEST:=${XDG_CONFIG_HOME:-$CYBR_HOME/.config}/cybrdots/manifest.toml}"
: "${CYBR_REGISTRY:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/components.toml}"

cybr::usage() {
  cat <<'EOF'
Usage: cybr <command> [args]

  list                 Show known components and which are enabled
  enable <component>   Clone, install deps, deploy loader + override
  disable <component>  Remove loader, drop from manifest, archive override
  sync                 Reconcile everything to the manifest (fresh-machine command)
  update [component]   git pull cache, show upstream diff, bump pinned SHA
  status               Show enabled components and pinned-vs-upstream
  diff <component>     Show upstream changes since the pinned SHA
EOF
}

# Read a key from a [component] section of the registry TOML.
cybr::reg_get() { # component, key
  awk -v sec="$1" -v key="$2" '
    /^\[/ { inset = ($0 == "[" sec "]") }
    inset && $0 ~ "^"key"[ \t]*=" {
      sub(/^[^=]*=[ \t]*/, ""); gsub(/^"|"$/, ""); print; exit
    }' "$CYBR_REGISTRY"
}

# List all component section names in registry order.
cybr::reg_components() {
  awk '/^\[/ { gsub(/^\[|\]$/, ""); print }' "$CYBR_REGISTRY"
}

# Is a component enabled (present in manifest)?
cybr::is_enabled() { # component
  [[ -f "$CYBR_MANIFEST" ]] && grep -q "^$1[[:space:]]*=" "$CYBR_MANIFEST"
}

cybr::cmd_list() {
  local c mark
  while IFS= read -r c; do
    if cybr::is_enabled "$c"; then mark="[x]"; else mark="[ ]"; fi
    printf '%s %s\n' "$mark" "$c"
  done < <(cybr::reg_components)
}

cybr::cache_dir() { printf '%s/%s' "$CYBR_CACHE" "$1"; }

# Clone if absent, else fetch. Leaves the repo on its default branch tip.
cybr::clone_or_update() { # component, repo_url
  local comp="${1:?usage: clone_or_update <component> <repo_url>}"
  local url="${2:?usage: clone_or_update <component> <repo_url>}"
  local dir; dir="$(cybr::cache_dir "$comp")"
  if [[ -d "$dir/.git" ]]; then
    git -C "$dir" fetch --quiet --all --tags
    local branch
    branch="$(git -C "$dir" rev-parse --abbrev-ref origin/HEAD)" || {
      echo "cybr: cannot resolve default branch for $comp" >&2; return 1
    }
    branch="${branch#origin/}"
    git -C "$dir" checkout --quiet "$branch"
    git -C "$dir" pull --quiet --ff-only
  else
    mkdir -p "$(dirname "$dir")"
    git clone --quiet "$url" "$dir"
  fi
}

# Pin to an exact commit (detached).
cybr::checkout() { # component, sha
  local dir; dir="$(cybr::cache_dir "$1")"
  git -C "$dir" checkout --quiet "$2"
}

# Current HEAD sha of a cached component.
cybr::head_sha() { # component
  git -C "$(cybr::cache_dir "$1")" rev-parse HEAD
}

cybr::target_dir() { printf '%s/%s' "$CYBR_HOME" "$(cybr::reg_get "$1" target)"; }
cybr::override_path() { # component -> absolute override file path
  local style; style="$(cybr::reg_get "$1" style)"
  case "$style" in
    hypr)  printf '%s/override.conf'  "$(cybr::target_dir "$1")" ;;
    jsonc) printf '%s/override.jsonc' "$(cybr::target_dir "$1")" ;;
    *)     printf '' ;;
  esac
}

# Symlink every top-level upstream file into the target dir EXCEPT the entry
# file (which becomes the loader) and the override file (user-owned). This makes
# upstream's internal `~/.config/...` references resolve through the symlinks.
# Safety: stale symlinks are replaced cleanly; a real (non-symlink) file or dir
# already at the target is moved to `<path>.pre-cybr.bak` before linking, so we
# never silently destroy user data or nest a link inside an existing dir.
cybr::mirror_upstream() { # component
  local dir target entry f base dest
  dir="$(cybr::cache_dir "$1")"; target="$(cybr::target_dir "$1")"
  entry="$(cybr::reg_get "$1" entry)"
  mkdir -p "$target"
  local had_nullglob=1; shopt -q nullglob || had_nullglob=0
  shopt -s nullglob
  for f in "$dir"/*; do
    base="$(basename "$f")"
    [[ "$base" == "$entry" ]] && continue
    [[ "$base" == "README.md" || "$base" == "LICENSE" ]] && continue
    dest="$target/$base"
    if [[ -L "$dest" ]]; then
      rm -f "$dest"                       # stale symlink: replace cleanly
    elif [[ -e "$dest" ]]; then           # real file/dir: back up, never destroy/nest
      if [[ -e "$dest.pre-cybr.bak" ]]; then rm -rf "$dest"; else mv "$dest" "$dest.pre-cybr.bak"; fi
    fi
    ln -sfn "$f" "$dest"
  done
  (( had_nullglob )) || shopt -u nullglob
}

# Create an empty override file (preserving any existing one).
cybr::scaffold_override() { # component
  local ov; ov="$(cybr::override_path "$1")"
  [[ -z "$ov" ]] && return 0
  [[ -e "$ov" ]] && return 0
  mkdir -p "$(dirname "$ov")"
  printf '# %s overrides — yours, wins over upstream (included last).\n' "$1" > "$ov"
}

# Write the loader (the entry file) chaining cached upstream entry -> override.
cybr::write_loader() { # component
  local style dir target entry ov
  style="$(cybr::reg_get "$1" style)"
  dir="$(cybr::cache_dir "$1")"; target="$(cybr::target_dir "$1")"
  entry="$(cybr::reg_get "$1" entry)"; ov="$(cybr::override_path "$1")"
  [[ "$style" == "none" || -z "$entry" ]] && return 0
  mkdir -p "$target"
  case "$style" in
    hypr)
      cat > "$target/$entry" <<EOF
# Loader (generated by cybr). Upstream read live from cache; override wins.
source = $dir/$entry
source = $ov
EOF
      ;;
    jsonc)
      cat > "$target/$entry" <<EOF
// Loader (generated by cybr). Upstream read live from cache; override wins.
{ "include": [ "$dir/$entry", "$ov" ] }
EOF
      ;;
  esac
}

# --- package manager (runtime detection) ---
cybr::pm() {
  if command -v paru >/dev/null; then echo paru
  elif command -v dnf >/dev/null; then echo dnf
  elif command -v apt >/dev/null; then echo apt
  else echo ""; fi
}
cybr::pm_missing() { # pkgs... -> prints those not installed
  local p; for p in "$@"; do
    case "$(cybr::pm)" in
      paru) paru -Qi "$p" >/dev/null 2>&1 || echo "$p" ;;
      dnf)  rpm -q "$p"  >/dev/null 2>&1 || echo "$p" ;;
      apt)  dpkg -s "$p" >/dev/null 2>&1 || echo "$p" ;;
      *)    echo "$p" ;;
    esac
  done
}
cybr::pm_install() { # pkgs...
  [[ $# -eq 0 ]] && return 0
  case "$(cybr::pm)" in
    paru) paru -S --needed --noconfirm "$@" ;;
    dnf)  sudo dnf install -y "$@" ;;
    apt)  sudo apt-get install -y "$@" ;;
    *)    echo "cybr: no supported package manager; install manually: $*" >&2 ;;
  esac
}
cybr::install_deps() { # component
  local deps missing
  deps="$(cybr::reg_get "$1" deps)"
  [[ -z "$deps" ]] && return 0
  # shellcheck disable=SC2086
  missing="$(cybr::pm_missing $deps)"
  [[ -z "$missing" ]] && { echo "  deps: all present"; return 0; }
  echo "  deps: installing $missing"
  # shellcheck disable=SC2086
  cybr::pm_install $missing
}

# --- manifest writers ---
cybr::manifest_set() { # component, sha
  mkdir -p "$(dirname "$CYBR_MANIFEST")"; touch "$CYBR_MANIFEST"
  local tmp; tmp="$(mktemp)"
  grep -v "^$1[[:space:]]*=" "$CYBR_MANIFEST" > "$tmp" || true
  printf '%s = "%s"\n' "$1" "$2" >> "$tmp"
  sort -o "$tmp" "$tmp"; mv "$tmp" "$CYBR_MANIFEST"
}
cybr::manifest_del() { # component
  [[ -f "$CYBR_MANIFEST" ]] || return 0
  local tmp; tmp="$(mktemp)"
  grep -v "^$1[[:space:]]*=" "$CYBR_MANIFEST" > "$tmp" || true
  if [[ -s "$tmp" ]]; then
    mv "$tmp" "$CYBR_MANIFEST"
  else
    rm -f "$tmp" "$CYBR_MANIFEST"
  fi
}
cybr::manifest_get() { # component -> sha
  [[ -f "$CYBR_MANIFEST" ]] || return 0
  grep "^$1[[:space:]]*=" "$CYBR_MANIFEST" | sed 's/^[^=]*=[ \t]*//; s/^"//; s/"$//'
}

# Deploy one component end-to-end (assumes cache already at desired sha).
cybr::deploy() { # component
  local style; style="$(cybr::reg_get "$1" style)"
  cybr::mirror_upstream "$1"
  if [[ "$style" != "none" ]]; then
    cybr::scaffold_override "$1"
    cybr::write_loader "$1"
  fi
}

cybr::cmd_enable() { # component
  local c="$1" repo
  cybr::reg_get "$c" repo >/dev/null || { echo "cybr: unknown component $c" >&2; return 1; }
  repo="${CYBR_TEST_REMOTE:-$(cybr::reg_get "$c" repo)}"
  echo "Enabling $c"
  cybr::clone_or_update "$c" "$repo"
  cybr::install_deps "$c"
  cybr::deploy "$c"
  cybr::manifest_set "$c" "$(cybr::head_sha "$c")"
  echo "  done. Override: $(cybr::override_path "$c")"
}

cybr::cmd_disable() { # component
  local c="$1" ov target entry
  target="$(cybr::target_dir "$c")"; entry="$(cybr::reg_get "$c" entry)"
  ov="$(cybr::override_path "$c")"
  [[ -n "$ov" && -e "$ov" ]] && mv "$ov" "$ov.disabled-$(cybr::head_sha "$c" 2>/dev/null || echo old)" 2>/dev/null || true
  [[ -n "$entry" && -e "$target/$entry" ]] && rm -f "$target/$entry"
  cybr::manifest_del "$c"
  echo "Disabled $c (loader removed; override archived; cache left intact)"
}

cybr::cmd_sync() {
  local c sha
  [[ -f "$CYBR_MANIFEST" ]] || { echo "Nothing enabled."; return 0; }
  while IFS= read -r c; do
    sha="$(cybr::manifest_get "$c")"
    echo "Syncing $c @ $sha"
    cybr::clone_or_update "$c" "${CYBR_TEST_REMOTE:-$(cybr::reg_get "$c" repo)}"
    [[ -n "$sha" ]] && cybr::checkout "$c" "$sha"
    cybr::install_deps "$c"
    cybr::deploy "$c"
  done < <(grep -oE '^[^ =]+' "$CYBR_MANIFEST")
}

# Stubs replaced in later tasks.
for _c in update status diff; do
  eval "cybr::cmd_$_c() { echo 'not implemented' >&2; return 1; }"
done
unset _c

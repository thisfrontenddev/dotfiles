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

# Stubs replaced in later tasks.
for _c in enable disable sync update status diff; do
  eval "cybr::cmd_$_c() { echo 'not implemented' >&2; return 1; }"
done
unset _c

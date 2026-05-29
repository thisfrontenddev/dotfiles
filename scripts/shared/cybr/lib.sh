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

# Stubs replaced in later tasks.
for _c in list enable disable sync update status diff; do
  eval "cybr::cmd_$_c() { echo 'not implemented' >&2; return 1; }"
done
unset _c

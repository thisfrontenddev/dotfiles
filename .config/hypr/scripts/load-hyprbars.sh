#!/usr/bin/env bash
set -u

plugin="$HOME/.local/lib/hyprland-plugins/hyprbars.so"
src="$HOME/.local/src/hyprland-plugins/hyprbars"

if hyprctl plugin list | grep -q '^Plugin hyprbars '; then
    exit 0
fi

running_hash="$(
    hyprctl version |
        sed -n 's/.* at commit \([0-9a-f]\{40\}\).*/\1/p' |
        head -n1
)"

plugin_matches_running_hyprland() {
    [ -n "$running_hash" ] &&
        [ -r "$plugin" ] &&
        strings "$plugin" | grep -q "$running_hash"
}

rebuild_plugin() {
    command -v make >/dev/null 2>&1 || return 1
    [ -d "$src" ] || return 1

    # A checkout older than the installed Hyprland won't compile against its
    # headers ("chase hyprland" commits land upstream after each release).
    git -C "$src" pull --ff-only >/dev/null 2>&1 || true

    make -C "$src" clean >/dev/null 2>&1 || true
    make -C "$src" all &&
        install -D -m 755 "$src/hyprbars.so" "$plugin"
}

load_plugin() {
    [ -x "$plugin" ] || return 1
    hyprctl plugin load "$plugin"
}

if ! plugin_matches_running_hyprland; then
    rebuild_plugin || true
fi

if load_plugin; then
    hyprctl reload
    exit 0
fi

if hyprpm reload -n; then
    hyprctl reload
    exit 0
fi

if rebuild_plugin && load_plugin; then
    hyprctl reload
    exit 0
fi

exit 1

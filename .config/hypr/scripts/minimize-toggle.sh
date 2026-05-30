#!/usr/bin/env bash
# minimize-toggle.sh — driven by the yellow hyprbars titlebar button.
#
#   Normal window    -> remember which workspace it's on, then stash it in the
#                       special:minimized scratchpad (silent, so the view stays).
#   Minimized window -> send it back to the workspace it came from and follow it.
#
# Origin workspace is recorded per window address under $XDG_RUNTIME_DIR.

state_dir="${XDG_RUNTIME_DIR:-/tmp}/hypr-minimized"
mkdir -p "$state_dir"

info=$(hyprctl activewindow -j)
addr=$(jq -r '.address' <<<"$info")
ws_name=$(jq -r '.workspace.name' <<<"$info")

# No focused window (e.g. empty scratchpad) — nothing to do.
if [ -z "$addr" ] || [ "$addr" = "null" ]; then
    exit 0
fi

if [ "$ws_name" = "special:minimized" ]; then
    # Restore: move back to the remembered workspace and follow it there.
    origin=$(cat "$state_dir/$addr" 2>/dev/null)
    if [ -n "$origin" ]; then
        hyprctl dispatch movetoworkspace "$origin,address:$addr"
        rm -f "$state_dir/$addr"
    else
        # Unknown origin (minimized before this script existed) — fall back.
        hyprctl dispatch movetoworkspace "previous,address:$addr"
    fi
else
    # Minimize: record current workspace id, then stash without following.
    ws_id=$(jq -r '.workspace.id' <<<"$info")
    echo "$ws_id" >"$state_dir/$addr"
    hyprctl dispatch movetoworkspacesilent "special:minimized,address:$addr"
fi

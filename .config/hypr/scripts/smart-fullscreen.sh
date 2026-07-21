#!/usr/bin/env bash
# True fullscreen for normal windows. For NTE, avoid compositor fullscreen
# because it resizes the game surface to the QHD monitor and makes the game
# switch back to 2560x1440.

set -u

mode="${1:-fullscreen}"

info=$(hyprctl activewindow -j 2>/dev/null) || exit 0
addr=$(jq -r '.address // empty' <<<"$info")
class=$(jq -r '.class // empty' <<<"$info")
title=$(jq -r '.title // empty' <<<"$info")

[ -n "$addr" ] || exit 0

if [ "$class" = "steam_app_default" ] && grep -Eq '^NTE[[:space:]]*$' <<<"$title"; then
    hyprctl dispatch "hl.dsp.window.fullscreen_state({internal=0, client=0})" >/dev/null 2>&1 || true
    hyprctl dispatch "hl.dsp.window.resize({x=1920, y=1080, exact=true})" >/dev/null 2>&1 || true
    hyprctl dispatch "hl.dsp.window.center()" >/dev/null 2>&1 || true
    hyprctl dispatch "hl.dsp.window.alter_zorder({mode='top', window='address:$addr'})" >/dev/null 2>&1 || true
    exit 0
fi

if [ "$mode" = "maximize" ]; then
    hyprctl dispatch "hl.dsp.window.fullscreen({mode=1})"
else
    hyprctl dispatch "hl.dsp.window.fullscreen({mode=0})"
fi

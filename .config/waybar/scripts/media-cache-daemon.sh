#!/bin/bash
# Watches playerctl metadata across all players and caches last known good metadata per player.
# Cider (Chromium MPRIS) briefly populates then clears metadata — this catches it.
# Usage: run in background, e.g. from sway config

CACHE_DIR="/tmp/.waybar-media-cache"
mkdir -p "$CACHE_DIR"

declare -A artists titles

playerctl --all-players --follow metadata 2>/dev/null | while read -r player key value; do
    [[ -z "$player" ]] && continue
    case "$key" in
        xesam:artist)
            if [[ -n "$value" ]]; then
                artists["$player"]="$value"
                title="${titles[$player]:-}"
                if [[ -n "$title" ]]; then
                    echo "${artists[$player]}	${title}" > "${CACHE_DIR}/${player}"
                fi
            fi
            ;;
        xesam:title)
            if [[ -n "$value" ]]; then
                titles["$player"]="$value"
                artist="${artists[$player]:-}"
                if [[ -n "$artist" ]]; then
                    echo "${artist}	${titles[$player]}" > "${CACHE_DIR}/${player}"
                fi
            fi
            ;;
    esac
done

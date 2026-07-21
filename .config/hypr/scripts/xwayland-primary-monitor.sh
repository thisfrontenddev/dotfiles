#!/usr/bin/env bash
# Make XWayland report the QHD monitor as primary. Some Proton/XWayland games
# only use XRandR monitor 0 for their resolution list.

set -u

primary_output="${1:-DP-5}"

for _ in $(seq 1 20); do
    if xrandr --output "$primary_output" --primary >/dev/null 2>&1; then
        exit 0
    fi
    sleep 1
done

exit 1

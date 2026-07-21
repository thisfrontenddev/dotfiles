#!/usr/bin/env bash

set -u

mode="${1:-fullscreen}"
output_dir="${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"

mkdir -p "$output_dir" || exit 1

timestamp=$(date +%Y%m%d-%H%M%S)
file="$output_dir/screenshot-${timestamp}-${mode}.png"
counter=1

while [ -e "$file" ]; do
    file="$output_dir/screenshot-${timestamp}-${mode}-${counter}.png"
    counter=$((counter + 1))
done

tmp=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/hypr-screenshot.XXXXXX.png") || exit 1
cleanup() {
    rm -f "$tmp"
}
trap cleanup EXIT

case "$mode" in
    fullscreen)
        grim "$tmp" || exit 1
        ;;
    area)
        geometry=$(slurp) || exit 0
        [ -n "$geometry" ] || exit 0
        grim -g "$geometry" "$tmp" || exit 1
        ;;
    *)
        printf 'usage: %s [fullscreen|area]\n' "$0" >&2
        exit 2
        ;;
esac

cp "$tmp" "$file" || exit 1
wl-copy --type image/png <"$tmp" || exit 1

if command -v notify-send >/dev/null 2>&1; then
    notify-send -a Hyprland "Screenshot saved" "$file"
fi

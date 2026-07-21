#!/usr/bin/env bash
# Keep NTE windows on-screen when the launcher restores a bad Windows-side
# position through Proton/XWayland.

set -u

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
lock_dir="$runtime_dir/nte-window-keeper.lock"

if ! mkdir "$lock_dir" 2>/dev/null; then
    exit 0
fi
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT

event_socket=""
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    event_socket="$runtime_dir/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
fi

min_visible_pixels=64

set_nte_xwayland_primary() {
    command -v xrandr >/dev/null 2>&1 || return 0
    [ -n "${DISPLAY:-}" ] || return 0

    xrandr --output DP-5 --primary >/dev/null 2>&1 || true
}

nte_offscreen_addresses() {
    local monitors
    monitors=$(hyprctl monitors -j 2>/dev/null) || return 0

    hyprctl clients -j 2>/dev/null | jq -r --argjson monitors "$monitors" --argjson min_visible "$min_visible_pixels" '
        .[]
        | select(.mapped == true)
        | select(.class == "steam_app_default")
        | . as $client
        | [
            $monitors[]
            | ([($client.at[0]), .x] | max) as $left
            | ([($client.at[1]), .y] | max) as $top
            | ([($client.at[0] + $client.size[0]), (.x + .width)] | min) as $right
            | ([($client.at[1] + $client.size[1]), (.y + .height)] | min) as $bottom
            | select((($right - $left) >= $min_visible) and (($bottom - $top) >= $min_visible))
        ] as $visible_intersections
        | select(
            ($visible_intersections | length) == 0
        )
        | "\($client.address)\t\($client.pid)"
    '
}

is_nte_process() {
    local pid=$1
    local cmdline

    cmdline=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)

    case "$cmdline" in
        *NTEGlobalGame.exe*|*NTEGlobalLauncher.exe*|*HTGame.exe*)
            return 0
            ;;
    esac

    return 1
}

ensure_nte_on_screen() {
    local addr pid

    while IFS=$'\t' read -r addr pid; do
        [ -n "$addr" ] || continue
        is_nte_process "$pid" || continue
        hyprctl dispatch "hl.dsp.focus({window='address:$addr'})" >/dev/null 2>&1 || true
        hyprctl dispatch "hl.dsp.window.center()" >/dev/null 2>&1 || true
        hyprctl dispatch "hl.dsp.window.alter_zorder({mode='top', window='address:$addr'})" >/dev/null 2>&1 || true
    done < <(nte_offscreen_addresses)
}

set_nte_xwayland_primary
ensure_nte_on_screen

if [ "${1:-}" = "--once" ]; then
    exit 0
fi

while true; do
    if [ -S "$event_socket" ] && command -v nc >/dev/null 2>&1; then
        while IFS= read -r event; do
            case "$event" in
                openwindow*|movewindow*|resizewindow*|fullscreen*|monitor*|configreloaded*)
                    set_nte_xwayland_primary
                    ensure_nte_on_screen
                    ;;
            esac
        done < <(nc -U "$event_socket" 2>/dev/null)
    else
        ensure_nte_on_screen
        sleep 2
    fi

    sleep 1
done

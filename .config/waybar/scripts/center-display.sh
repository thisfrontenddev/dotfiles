#!/bin/bash
# Shows media info when playing on this monitor, otherwise shows focused window title
# Usage: center-display.sh <output-name>

OUTPUT="$1"
SWAYSOCK=$(ls /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -1)
export SWAYSOCK

TREE=$(swaymsg -t get_tree 2>/dev/null)

show_window() {
    title=$(echo "$TREE" | _WB_OUTPUT="$OUTPUT" /usr/bin/python3 -c "
import json, sys, os
output = os.environ['_WB_OUTPUT']

def find_focused(node):
    if node.get('focused'):
        return node.get('name', '')
    for n in node.get('nodes', []) + node.get('floating_nodes', []):
        r = find_focused(n)
        if r is not None:
            return r
    return None

def find_first_window(node):
    if node.get('type') in ('con', 'floating_con') and node.get('name'):
        return node.get('name', '')
    for n in node.get('nodes', []) + node.get('floating_nodes', []):
        r = find_first_window(n)
        if r:
            return r
    return None

t = json.load(sys.stdin)
for node in t.get('nodes', []):
    if node.get('name') == output:
        # Try focused window first
        r = find_focused(node)
        if r:
            print(r)
            sys.exit()
        # Fall back to first window in any workspace on this output
        for ws in node.get('nodes', []):
            r = find_first_window(ws)
            if r:
                print(r)
                sys.exit()
print('')
")
    if [[ -n "$title" ]]; then
        echo "{\"text\": \"$(echo "$title" | sed 's/"/\\"/g')\", \"class\": \"window\"}"
    else
        echo "{\"text\": \"\", \"class\": \"empty\"}"
    fi
}

status=$(playerctl status 2>/dev/null)

if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
    player_name=$(playerctl metadata --format '{{playerName}}' 2>/dev/null)

    # Map player names to possible app_ids/wm_classes
    # e.g. playerctl reports "firefox" for Zen Browser, Spotify as "spotify", etc.
    on_this_output=$(echo "$TREE" | _WB_OUTPUT="$OUTPUT" _WB_PLAYER="$player_name" /usr/bin/python3 -c "
import json, sys, os
output = os.environ['_WB_OUTPUT']
player = os.environ['_WB_PLAYER'].lower()

# Map of player names to app_id patterns they could match
player_map = {
    'firefox': ['firefox', 'zen', 'librewolf', 'waterfox', 'floorp'],
    'chromium': ['chromium', 'chrome', 'brave', 'vivaldi', 'edge', 'cider'],
    'spotify': ['spotify'],
    'vlc': ['vlc'],
    'mpv': ['mpv'],
}
patterns = player_map.get(player, [player])

def find_app(node, current_output=None):
    if node.get('type') == 'output':
        current_output = node.get('name')
    if node.get('type') in ('con', 'floating_con'):
        app_id = (node.get('app_id') or '').lower()
        wm_class = (node.get('window_properties', {}).get('class', '') or '').lower()
        for p in patterns:
            if p in app_id or p in wm_class:
                if current_output == output:
                    print('yes')
                    sys.exit()
    for n in node.get('nodes', []) + node.get('floating_nodes', []):
        find_app(n, current_output)
t = json.load(sys.stdin)
find_app(t)
print('no')
")

    if [[ "$on_this_output" == "yes" ]]; then
        artist=$(playerctl metadata artist 2>/dev/null)
        title=$(playerctl metadata title 2>/dev/null)

        # Fall back to cached metadata (media-cache-daemon.sh catches brief MPRIS updates from Cider)
        if [[ -z "$artist" && -z "$title" && -f "/tmp/.waybar-media-cache/${player_name}" ]]; then
            IFS=$'\t' read -r artist title _ < "/tmp/.waybar-media-cache/${player_name}"
        fi

        icon=""
        [[ "$status" == "Paused" ]] && icon=""
        if [[ -n "$artist" && -n "$title" ]]; then
            text="$icon $artist - $title"
        elif [[ -n "$title" ]]; then
            text="$icon $title"
        else
            text="$icon Media"
        fi
        echo "{\"text\": \"$(echo "$text" | sed 's/"/\\"/g')\", \"class\": \"music\"}"
    else
        show_window
    fi
else
    show_window
fi

#!/bin/bash
# Outputs class based on whether media is playing on this output
# Usage: center-arrow.sh <output-name>
OUTPUT="$1"
SWAYSOCK=$(ls /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -1)
export SWAYSOCK

status=$(playerctl status 2>/dev/null)
if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
    player_name=$(playerctl metadata --format '{{playerName}}' 2>/dev/null)
    on_this=$(swaymsg -t get_tree 2>/dev/null | _WB_OUTPUT="$OUTPUT" _WB_PLAYER="$player_name" /usr/bin/python3 -c "
import json, sys, os
output = os.environ['_WB_OUTPUT']
player = os.environ['_WB_PLAYER'].lower()
player_map = {
    'firefox': ['firefox', 'zen', 'librewolf', 'waterfox', 'floorp'],
    'chromium': ['chromium', 'chrome', 'brave', 'vivaldi', 'edge'],
    'spotify': ['spotify'], 'vlc': ['vlc'], 'mpv': ['mpv'], 'cider': ['cider'],
}
patterns = player_map.get(player, [player])
def find(node, cur=None):
    if node.get('type') == 'output': cur = node.get('name')
    if node.get('type') in ('con', 'floating_con'):
        app_id = (node.get('app_id') or '').lower()
        wm_class = (node.get('window_properties', {}).get('class', '') or '').lower()
        for p in patterns:
            if p in app_id or p in wm_class:
                if cur == output: print('yes'); sys.exit()
    for n in node.get('nodes', []) + node.get('floating_nodes', []): find(n, cur)
find(json.load(sys.stdin))
print('no')
")
    if [[ "$on_this" == "yes" ]]; then
        echo '{"text": "  ", "class": "music"}'
        exit
    fi
fi
echo '{"text": "  ", "class": "window"}'

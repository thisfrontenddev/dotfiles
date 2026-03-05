#!/bin/bash
# Audio output/input switcher using rofi + wpctl
# Usage: audio-switch.sh [output|input]

MODE="${1:-output}"

if [[ "$MODE" == "output" ]]; then
    SECTION="Sinks"
    LABEL="Audio Output"
elif [[ "$MODE" == "input" ]]; then
    SECTION="Sources"
    LABEL="Audio Input"
else
    echo "Usage: audio-switch.sh [output|input]"
    exit 1
fi

# Parse wpctl status — extract lines between our section and the next section
devices=$(wpctl status | sed -n "/─ ${SECTION}:/,/─ [A-Z]/p" | grep -E '[0-9]+\.' | while read -r line; do
    # Check if active
    active=""
    echo "$line" | grep -q '\*' && active=" ●"
    # Extract ID and name
    id=$(echo "$line" | grep -oP '[0-9]+(?=\.)' | head -1)
    name=$(echo "$line" | sed 's/.*[0-9]\+\. //' | sed 's/\[vol:.*//' | sed 's/[[:space:]]*$//')
    [[ -n "$id" && -n "$name" ]] && echo "${id}  ${name}${active}"
done)

if [[ -z "$devices" ]]; then
    notify-send "Audio Switch" "No devices found"
    exit 1
fi

selected=$(echo "$devices" | rofi -dmenu -i -p "$LABEL" -theme-str 'window {width: 40%;}')

if [[ -n "$selected" ]]; then
    sel_id=$(echo "$selected" | awk '{print $1}')
    wpctl set-default "$sel_id"
    sel_name=$(echo "$selected" | sed "s/^${sel_id}  //; s/ ●$//")
    notify-send "Audio Switch" "${LABEL}: ${sel_name}"
fi

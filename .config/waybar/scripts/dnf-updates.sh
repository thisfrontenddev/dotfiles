#!/bin/bash
# DNF update checker for waybar (replaces waybar-updates AUR package)
# Outputs JSON for waybar custom module

count=$(dnf check-update --quiet 2>/dev/null | grep -c '^\S')

if [ "$count" -gt 0 ]; then
    echo "{\"text\": \"$count\", \"tooltip\": \"$count updates available\", \"alt\": \"pending-updates\", \"class\": \"pending-updates\"}"
else
    echo "{\"text\": \"\", \"tooltip\": \"System up to date\", \"alt\": \"updated\", \"class\": \"updated\"}"
fi

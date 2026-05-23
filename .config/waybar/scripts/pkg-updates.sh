#!/usr/bin/env bash
# Pending-updates indicator for waybar — outputs JSON for the custom/updates module.
#
# Detects the local package manager at runtime:
#   Arch:    paru -Qu       (covers repo + AUR in one query, no root needed)
#   Fedora:  dnf check-update
#   Debian:  apt list --upgradable
#
# Notes on paru -Qu: it reads from the local sync DB. Whenever you run `paru -Syu`
# the DB refreshes and the count is accurate. If you go weeks without syncing,
# the count may understate — fine for a passive indicator.

if command -v paru >/dev/null 2>&1; then
    count=$(paru -Qu 2>/dev/null | wc -l)
elif command -v dnf >/dev/null 2>&1; then
    count=$(dnf check-update --quiet 2>/dev/null | grep -c '^\S' || true)
elif command -v apt >/dev/null 2>&1; then
    count=$(apt list --upgradable 2>/dev/null | grep -c '/')
else
    count=0
fi

if [ "$count" -gt 0 ]; then
    echo "{\"text\": \"$count\", \"tooltip\": \"$count updates available\", \"alt\": \"pending-updates\", \"class\": \"pending-updates\"}"
else
    echo "{\"text\": \"\", \"tooltip\": \"System up to date\", \"alt\": \"updated\", \"class\": \"updated\"}"
fi

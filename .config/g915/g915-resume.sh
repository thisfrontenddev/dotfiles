#!/usr/bin/env bash
# Re-apply per-key G915 TKL lighting after resume from suspend.
# The onboard profile provides a blue/yellow static fallback;
# this script overlays per-key colors once the OS is back.

G915_LED="/home/void/.config/g915/bin/g915-led"

# Modifier/special keys in electric yellow, everything else blue
apply_lighting() {
    "$G915_LED" direct \
        backtick=FFFF33 lshift=FFFF33 rshift=FFFF33 \
        lctrl=FFFF33 rctrl=FFFF33 lwin=FFFF33 \
        lalt=FFFF33 ralt=FFFF33 capslock=FFFF33 \
        tab=FFFF33 fn=FFFF33 menu=FFFF33 \
        brightness=FFFF33 play=FFFF33 mute=FFFF33 \
        next=FFFF33 prev=FFFF33 logo=FFFF33 \
        --base 0000FF
}

LOG="/tmp/g915-resume.log"

case "$1" in
    post)
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Resume triggered, waiting for re-enumerate..." >> "$LOG"
        # Give the keyboard time to re-enumerate via KVM
        sleep 5
        if apply_lighting >> "$LOG" 2>&1; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lighting applied successfully" >> "$LOG"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to apply lighting (exit $?)" >> "$LOG"
        fi
        ;;
esac

#!/usr/bin/env bash
# Re-apply per-key G915 TKL lighting after resume from suspend.
# The onboard profile provides a blue/yellow static fallback;
# this script overlays per-key colors once the OS is back.

G915_LED="/home/void/.config/logitech/g915-led"

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

case "$1" in
    post)
        # Give the keyboard time to re-enumerate via KVM
        sleep 5
        apply_lighting
        ;;
esac

function swaymsg --description 'swaymsg with auto-resolved SWAYSOCK (survives session changes)'
    # `set` tolerates an empty glob, so this is safe when no sway socket exists.
    set -l sock /run/user/(id -u)/sway-ipc.*.sock
    set -q sock[1]; and set -lx SWAYSOCK $sock[1]
    command swaymsg $argv
end

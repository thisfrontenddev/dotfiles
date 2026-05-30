# Point fish at the persistent systemd-managed ssh-agent (ssh-agent.service).
#
# environment.d/ssh-agent.conf sets SSH_AUTH_SOCK for systemd --user services,
# but this Hyprland session (SDDM -> start-hyprland) doesn't import the systemd
# user environment, so interactive shells don't inherit it. Set it here directly;
# the socket path is fixed by ssh-agent.service (-a $XDG_RUNTIME_DIR/ssh-agent.socket).
if not set -q XDG_RUNTIME_DIR
    set -gx XDG_RUNTIME_DIR /run/user/(id -u)
end
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"

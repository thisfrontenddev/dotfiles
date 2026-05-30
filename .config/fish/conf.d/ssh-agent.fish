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

# The signing key is passphrase-protected, so the agent is empty after a reboot.
# On an interactive shell, if the agent has no key loaded yet, offer to add it
# (one passphrase prompt). Once loaded it persists for the session, so this stops
# asking. Decline with 'n' (or empty answer skips a single time).
if status is-interactive; and test -S "$SSH_AUTH_SOCK"; and not ssh-add -l >/dev/null 2>&1; and test -f ~/.ssh/id_ed25519
    read -P "[ssh] key not loaded — add it for git signing? [Y/n] " -l _ssh_reply
    if test -z "$_ssh_reply"; or string match -qi y "$_ssh_reply"
        ssh-add ~/.ssh/id_ed25519
    end
end

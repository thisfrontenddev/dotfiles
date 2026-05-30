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
# If no key is loaded yet, load it pulling the passphrase from gnome-keyring — no
# prompt. pam_gnome_keyring unlocks the login keyring at SDDM login, so the lookup
# in ssh-askpass-keyring just works. Store the passphrase once with:
#   secret-tool store --label="ssh id_ed25519" ssh-key id_ed25519
if test -S "$SSH_AUTH_SOCK"; and test -f ~/.ssh/id_ed25519; and not ssh-add -l >/dev/null 2>&1
    if secret-tool lookup ssh-key id_ed25519 >/dev/null 2>&1
        env SSH_ASKPASS="$HOME/.local/bin/ssh-askpass-keyring" SSH_ASKPASS_REQUIRE=force \
            ssh-add ~/.ssh/id_ed25519 >/dev/null 2>&1
    else if status is-interactive
        echo "[ssh] signing-key passphrase not in keyring yet. Store it once with:"
        echo '      secret-tool store --label="ssh id_ed25519" ssh-key id_ed25519'
    end
end

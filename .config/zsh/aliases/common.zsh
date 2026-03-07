alias attach="tmux new -A -s personal"
alias attach-work="tmux new -A -s work"

alias claude-work="CLAUDE_CONFIG_DIR=~/.config/claude-work claude"
alias alt="claude --dangerously-skip-permissions"

alias dot="/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME"
alias zdot="$EDITOR ~/.zshrc"

alias ll="eza --git --long --group --icons=auto --group-directories-first --all"

alias defaultnode="fnm use system"

alias docker="podman"
alias docker-compose="podman-compose"

# Sway: always resolve the current IPC socket (survives tmux/session changes)
if [[ "$OSTYPE" != darwin* ]]; then
  alias swaymsg='SWAYSOCK=$(ls /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -1) command swaymsg'
fi


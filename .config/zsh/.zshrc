export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Source the main init
if [[ -f "${XDG_CONFIG_HOME}/zsh/init.zsh" ]]; then
  source "${XDG_CONFIG_HOME}/zsh/init.zsh"
fi

# Display system info and startup time on interactive shells
if [[ -o interactive && $+commands[fastfetch] -eq 1 ]]; then
  fastfetch
  if [[ -n "$__zsh_start" ]]; then
    local __zsh_end=$EPOCHREALTIME
    local __zsh_ms=$(( (__zsh_end - __zsh_start) * 1000 ))
    printf '\e[2m%.0fms to interactive prompt\e[0m\n\n' "$__zsh_ms"
    unset __zsh_start
  fi
fi

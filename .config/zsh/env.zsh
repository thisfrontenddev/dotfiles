[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# Source secrets (tokens, keys) — not tracked in dotfiles
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/secrets.zsh" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/secrets.zsh"

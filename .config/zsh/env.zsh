. "$HOME/.cargo/env"

# Source secrets (tokens, keys) — not tracked in dotfiles
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/secrets.zsh" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/secrets.zsh"

# Cap Node.js heap per process to prevent memory pressure with many concurrent instances
export NODE_OPTIONS="--max-old-space-size=512"

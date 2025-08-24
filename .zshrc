export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

if [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Check if init.zsh exists and source it
if [[ -f "${XDG_CONFIG_HOME}/zsh/init.zsh" ]]; then
  source "${XDG_CONFIG_HOME}/zsh/init.zsh"
else
  echo "Warning: ${XDG_CONFIG_HOME}/zsh/init.zsh not found" >&2
fi

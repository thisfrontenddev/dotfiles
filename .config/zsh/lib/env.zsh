typeset -U PATH path  # Deduplicate PATH automatically

# ── Cargo ──
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# ── OS-specific environment ──
if [[ "$OSTYPE" == darwin* ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
  export PNPM_HOME="$HOME/Library/pnpm"

  path=(
    /opt/homebrew/bin
    /opt/homebrew/sbin
    $path
  )
else
  # Linux
  [[ -d "/usr/lib/jvm/java" ]] && export JAVA_HOME="/usr/lib/jvm/java"
  export PNPM_HOME="$HOME/.local/share/pnpm"

  path=(
    $HOME/.nix-profile/bin
    $path
  )
fi

# ── Always available ──
path=(
  $HOME/.local/bin
  $path
)

# ── Optional tools (only added if installed) ──
[[ -d "$HOME/.cargo/bin" ]]                && path+=("$HOME/.cargo/bin")
[[ -d "$HOME/.console-ninja/.bin" ]]       && path+=("$HOME/.console-ninja/.bin")
[[ -d "$HOME/.opencode/bin" ]]             && path+=("$HOME/.opencode/bin")
[[ -d "$HOME/.antigravity/antigravity/bin" ]] && path+=("$HOME/.antigravity/antigravity/bin")
[[ -d "$HOME/.lmstudio/bin" ]]             && path+=("$HOME/.lmstudio/bin")
[[ -d "$PNPM_HOME" ]]                      && path+=("$PNPM_HOME")
[[ -d "${ANDROID_HOME}/emulator" ]]        && path+=("${ANDROID_HOME}/emulator")
[[ -d "${ANDROID_HOME}/platform-tools" ]]  && path+=("${ANDROID_HOME}/platform-tools")
[[ -d "/opt/homebrew/opt/postgresql@15/bin" ]] && path+=("/opt/homebrew/opt/postgresql@15/bin")

export PATH

# ── Secrets (tokens, keys) — not tracked in dotfiles ──
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/secrets.zsh" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/secrets.zsh"

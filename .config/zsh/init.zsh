#!/usr/bin/env zsh

# ============================================================================
# INITIAL SETUP
# ============================================================================

# Set XDG directories (if not already set)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Zsh configuration directory
export ZSH_CONFIG="${XDG_CONFIG_HOME}/zsh"

# ============================================================================
# LOAD LIBRARY FILES
# ============================================================================

# Load all library files (prompt, key-bindings, etc.)
if [[ -d "${ZSH_CONFIG}/lib" ]]; then
  for lib_file in "${ZSH_CONFIG}"/lib/*.zsh(N); do
    #echo "Loading lib file : ${lib_file}"
    source "${lib_file}"
  done
fi

# ============================================================================
# LOAD FUNCTIONS
# ============================================================================

# Autoload functions (more efficient, lazy loading)
if [[ -d "${ZSH_CONFIG}/functions" ]]; then
  fpath=("${ZSH_CONFIG}/functions" $fpath)
  autoload -Uz ${ZSH_CONFIG}/functions/*(.:t:r)
fi

# ============================================================================
# LOAD ALIASES
# ============================================================================

# Load all alias files
if [[ -d "${ZSH_CONFIG}/aliases" ]]; then
  for alias_file in "${ZSH_CONFIG}"/aliases/*.zsh(N); do
    #echo "Loading aliases file : ${alias_file}"
    source "${alias_file}"
  done
fi

# ============================================================================
# LOAD CUSTOM COMPLETIONS
# ============================================================================

# Add custom completions directory to fpath
if [[ -d "${ZSH_CONFIG}/completions" ]]; then
  fpath=("${ZSH_CONFIG}/completions" $fpath)
fi





. /opt/homebrew/opt/asdf/libexec/asdf.sh

EDITOR=/opt/homebrew/bin/nvim

PATH=~/.console-ninja/.bin:$PATH

# pnpm
export PNPM_HOME="/Users/null/Library/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home

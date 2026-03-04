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

# Use first available editor
if (( $+commands[nvim] )); then
  export EDITOR=nvim
elif (( $+commands[vim] )); then
  export EDITOR=vim
else
  export EDITOR=vi
fi

# ============================================================================
# LOAD LIBRARY FILES
# ============================================================================

# Load all library files (prompt, key-bindings, etc.)
if [[ -d "${ZSH_CONFIG}/lib" ]]; then
  for lib_file in "${ZSH_CONFIG}"/lib/*.zsh(N); do
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

# ============================================================================
# COMPILE ZSH FILES IN BACKGROUND
# ============================================================================

{
  local f
  for f in ~/.zshrc ~/.zshenv ~/.zprofile \
           ${ZSH_CONFIG}/**/*.zsh(N); do
    if [[ ! -f "${f}.zwc" || "${f}" -nt "${f}.zwc" ]]; then
      zcompile "${f}" 2>/dev/null
    fi
  done
} &!

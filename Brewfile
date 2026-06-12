# Brewfile — macOS packages and apps
# Usage: brew bundle

tap "homebrew/bundle"
tap "nikitabobko/tap"

def optional_cask?(name)
  selected = ENV.fetch("BREW_OPTIONAL_CASKS", "").split(/[,\s]+/).reject(&:empty?)

  selected.include?("all") || selected.include?(name)
end

# ── CLI tools ──

brew "bat"          # cat with syntax highlighting
brew "btop"         # System monitor
brew "cloc"         # Count lines of code
brew "commitizen"   # Conventional commits
brew "eza"          # Modern ls
brew "fastfetch"    # System info
brew "fish"         # Shell
brew "ffmpeg"       # Video transcoder
brew "fnm"          # Node version manager
brew "fzf"          # Fuzzy finder
brew "gh"           # GitHub CLI
brew "imagemagick"  # Image conversion
brew "lazygit"      # Git TUI
brew "neovim"       # Text editor
brew "node"         # Node.js
brew "pnpm"         # Package manager
brew "ripgrep"      # Modern grep
brew "rustup"       # Rust toolchain
brew "starship"     # Shell prompt
brew "tldr"         # Simplified man pages
brew "tmux"         # Terminal multiplexer
brew "watchman"     # File watcher

# ── Casks ──


# Browsers
cask "arc"
cask "firefox"
cask "google-chrome"

# Comms
cask "discord"
cask "slack"
cask "whatsapp" if optional_cask?("whatsapp")

# Containers
cask "orbstack"

# Fonts
cask "font-geist"
cask "font-geist-mono"
cask "font-geist-mono-nerd-font"
cask "font-inter"
cask "font-jetbrains-mono"
cask "font-jetbrains-mono-nerd-font"
cask "font-space-mono"
cask "font-space-mono-nerd-font"

# IDE / Agent Harnesses
cask "conductor"
cask "cursor"
cask "zed"

# Mail
cask "notion-mail"

# Media
cask "iina"         # Video player
cask "shottr"       # Screenshot tool

# Notes
cask "obsidian"
cask "notion" if optional_cask?("notion")

# Project management
cask "linear-linear" if optional_cask?("linear-linear")

# Security
cask "1password"
cask "1password-cli"
cask "little-snitch" if optional_cask?("little-snitch")
cask "micro-snitch" if optional_cask?("micro-snitch")

# Terminals
cask "alacritty"
cask "ghostty"
cask "iterm2"

# UI/UX
cask "figma"
cask "spline" if optional_cask?("spline")

# Spotlight replacement
cask "raycast"

# Streaming
cask "keycastr"
cask "obs" if optional_cask?("obs")

# Utilities
cask "aerospace"
cask "appcleaner"
cask "avifquicklook"
cask "caffeine"
cask "keyboardcleantool"
cask "mediamate"
cask "minisim"
cask "spacelauncher"

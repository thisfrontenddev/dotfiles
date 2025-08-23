if ! (which starship >/dev/null); then
    echo "Starship not installed, skipping initialization."
else
    eval "$(starship init zsh)"
fi

if ! (which fnm >/dev/null); then
    echo "fnm not installed, skipping initialization."
else
    eval "$(fnm env --use-on-cd)"
fi

. /opt/homebrew/opt/asdf/libexec/asdf.sh

# Add function directory to fpath
fpath=(~/.config/zsh/functions $fpath)

# Autoload the function
autoload -Uz convert-images

# Add aliases separately since they can't be autoloaded
alias jpg2avif='convert-images jpg avif'
alias png2avif='convert-images png avif'
alias jpg2webp='convert-images jpg webp'

EDITOR=/opt/homebrew/bin/nvim

alias g="git"
alias gb="git branch"
alias gf="git fetch"
alias grb="git rebase"
alias ga="git add"
alias gd="git diff"
alias gst="git status"
alias gc="git commit"
alias gco="git checkout"
alias gp="git push"
alias gfgrb="git fetch && git rebase"
alias gs="git stash"
alias gsp="git stash pop"
alias grs="git restore"
alias please="git push --force-with-lease"
alias again="git commit --amend --no-edit"

alias ll="eza --git --long --group --icons=auto --group-directories-first --all"
alias dot="/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME"
alias zdot="$EDITOR ~/.zshrc"

alias defaultnode="fnm use system"

# Create a file and its parent directories if they don't exist
# Usage: mktouch /path/to/file.txt
mktouch() {
  for file in "$@"; do
    mkdir -p "$(dirname "$file")" && touch "$file"
  done
}

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

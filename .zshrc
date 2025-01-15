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
alias config="/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME"
alias zconfig="code ~/.zshrc"

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

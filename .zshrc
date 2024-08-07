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

alias ll="eza --git --long --group --icons=auto --group-directories-first --all"
alias config="/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME"
alias zconfig="code ~/.zshrc"

PATH=~/.console-ninja/.bin:$PATH

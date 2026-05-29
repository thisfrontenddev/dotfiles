function dot --description 'Manage the dotfiles bare repo' --wraps git
    /usr/bin/git --git-dir=$HOME/.cfg --work-tree=$HOME $argv
end

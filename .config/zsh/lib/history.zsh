export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
export HISTSIZE=50000
export SAVEHIST=50000

setopt EXTENDED_HISTORY       # Timestamp in history
setopt HIST_EXPIRE_DUPS_FIRST # Delete duplicates first
setopt HIST_IGNORE_DUPS       # Ignore consecutive duplicates
setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicates
setopt HIST_IGNORE_SPACE      # Ignore commands starting with space
setopt HIST_FIND_NO_DUPS      # No duplicates in search
setopt HIST_SAVE_NO_DUPS      # No duplicates when saving
setopt SHARE_HISTORY          # Share history between sessions
setopt INC_APPEND_HISTORY     # Append immediately, not at exit

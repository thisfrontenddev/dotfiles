# Command abbreviations — expand inline as you type.
# No interactive guard on purpose: abbreviations are inert in non-interactive
# shells, and leaving them ungated keeps them verifiable with `abbr -q`.

# ── git ──
abbr -a g git
abbr -a gb git branch
abbr -a gf git fetch
abbr -a grb git rebase
abbr -a ga git add
abbr -a gd git diff
abbr -a gst git status
abbr -a gc git commit
abbr -a gco git checkout
abbr -a gp git push
abbr -a gfgrb 'git fetch && git rebase'
abbr -a gs git stash
abbr -a gsp git stash pop
abbr -a grs git restore
abbr -a please git push --force-with-lease
abbr -a again git commit --amend --no-edit

# ── common ──
abbr -a attach tmux new -A -s personal
abbr -a attach-work tmux new -A -s work
abbr -a alt claude --dangerously-skip-permissions
abbr -a claude-work 'env CLAUDE_CONFIG_DIR=$HOME/.config/claude-work claude'
abbr -a ll eza --git --long --group --icons=auto --group-directories-first --all
abbr -a defaultnode fnm use system
abbr -a docker podman
abbr -a docker-compose podman-compose

# ── image conversion ──
abbr -a jpg2avif convert-images jpg avif
abbr -a png2avif convert-images png avif
abbr -a jpg2webp convert-images jpg webp

# ── edit fish config (replaces zsh's `zdot`) ──
abbr -a fdot '$EDITOR ~/.config/fish'

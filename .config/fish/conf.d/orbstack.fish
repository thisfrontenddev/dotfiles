# OrbStack shell integration (macOS only) — interactive only.
status is-interactive; or return
test (uname) = Darwin; or return
test -f ~/.orbstack/shell/init.fish; and source ~/.orbstack/shell/init.fish 2>/dev/null

# ~/.config/fish/conf.d/00-env.fish
# Environment + PATH. Runs for ALL fish sessions (no interactive guard) so
# editors and scripts see the same environment.

# ── XDG base directories ──
set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME $HOME/.config
set -q XDG_DATA_HOME;   or set -gx XDG_DATA_HOME   $HOME/.local/share
set -q XDG_CACHE_HOME;  or set -gx XDG_CACHE_HOME  $HOME/.cache
set -q XDG_STATE_HOME;  or set -gx XDG_STATE_HOME  $HOME/.local/state

# ── Editor (first available) ──
if type -q nvim
    set -gx EDITOR nvim
else if type -q vim
    set -gx EDITOR vim
else
    set -gx EDITOR vi
end

# ── OS-specific environment ──
switch (uname)
    case Darwin
        set -gx ANDROID_HOME $HOME/Library/Android/sdk
        set -gx JAVA_HOME /Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home
        set -gx PNPM_HOME $HOME/Library/pnpm
        fish_add_path -gp /opt/homebrew/bin /opt/homebrew/sbin
    case '*'
        # Linux. No Nix here — ~/.nix-profile/bin is intentionally omitted
        # (Nix was Fedora-only and that config is being retired).
        test -d /usr/lib/jvm/java; and set -gx JAVA_HOME /usr/lib/jvm/java
        set -gx PNPM_HOME $HOME/.local/share/pnpm
end

# ── Cargo ──
test -f $HOME/.cargo/env.fish; and source $HOME/.cargo/env.fish

# ── PATH: high priority (prepend) ──
fish_add_path -gp $HOME/.local/bin

# ── PATH: optional tools (append, only if the dir exists) ──
for dir in \
        $HOME/.cargo/bin \
        $HOME/.console-ninja/.bin \
        $HOME/.opencode/bin \
        $HOME/.antigravity/antigravity/bin \
        $HOME/.lmstudio/bin \
        $PNPM_HOME \
        $ANDROID_HOME/emulator \
        $ANDROID_HOME/platform-tools \
        /opt/homebrew/opt/postgresql@15/bin
    test -d $dir; and fish_add_path -ga $dir
end

# ── Secrets (untracked) ──
test -f $XDG_CONFIG_HOME/fish/secrets.fish; and source $XDG_CONFIG_HOME/fish/secrets.fish

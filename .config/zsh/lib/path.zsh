typeset -U PATH path  # Deduplicate PATH automatically

# ── OS Detection ──
if [[ "$OSTYPE" == darwin* ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
  export PNPM_HOME="$HOME/Library/pnpm"

  path=(
    /opt/homebrew/bin
    /opt/homebrew/sbin
    /opt/homebrew/opt/postgresql@15/bin
    $HOME/.cargo/bin
    $HOME/Library/pnpm
    $HOME/.local/bin
    $HOME/.console-ninja/.bin
    $HOME/.opencode/bin
    $HOME/.antigravity/antigravity/bin
    $ANDROID_HOME/emulator
    $ANDROID_HOME/platform-tools
    $path
  )
else
  # Linux
  export ANDROID_HOME="$HOME/Android/Sdk"
  [[ -d "/usr/lib/jvm/java" ]] && export JAVA_HOME="/usr/lib/jvm/java"
  export PNPM_HOME="$HOME/.local/share/pnpm"

  path=(
    /home/linuxbrew/.linuxbrew/bin
    /home/linuxbrew/.linuxbrew/sbin
    $HOME/.cargo/bin
    $HOME/.local/share/pnpm
    $HOME/.local/bin
    $HOME/.console-ninja/.bin
    $HOME/.opencode/bin
    $HOME/.antigravity/antigravity/bin
    $ANDROID_HOME/emulator
    $ANDROID_HOME/platform-tools
    $path
  )
fi

export PATH

typeset -U PATH path  # Deduplicate PATH automatically

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

export PATH

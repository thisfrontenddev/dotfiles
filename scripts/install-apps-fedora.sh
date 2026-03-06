#!/usr/bin/env bash
set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILED=()

run_step() {
  local name="$1"; shift
  if ! "$@"; then
    echo "    FAILED: $name"
    FAILED+=("$name")
  fi
}

echo "=== Fedora App & Package Installation ==="

# ── DNF performance tuning ──
if ! grep -q 'max_parallel_downloads' /etc/dnf/dnf.conf; then
  echo "==> Tuning DNF config..."
  echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf >/dev/null
fi

# ── Drivers (NVIDIA, RPM Fusion) ──
run_step "Drivers" bash "$SCRIPTS_DIR/install-drivers-fedora.sh"

# ── System packages (dnf) ──
run_step "System packages" bash -c '
  echo "==> Installing system packages..."
  sudo dnf install -y --skip-unavailable \
    zsh git gcc gcc-c++ cmake ninja-build clang lld \
    golang java-latest-openjdk-devel \
    podman podman-compose \
    neovim tmux fzf \
    htop btop ripgrep fd-find bat jq yq \
    strace ltrace hyperfine tokei \
    fastfetch ImageMagick ffmpeg \
    pipx snapper \
    fontconfig \
    gh cloc tldr pnpm
'

# ── Sway ecosystem (dnf) ──
run_step "Sway ecosystem" bash -c '
  echo "==> Installing Sway ecosystem..."
  sudo dnf install -y --skip-unavailable \
    swayfx waybar wofi SwayNotificationCenter swaybg swaylock swayidle \
    grim slurp wl-clipboard sway-systemd
'

# ── GNOME extras (dnf) ──
run_step "GNOME extras" bash -c '
  echo "==> Installing GNOME extras..."
  sudo dnf install -y --skip-unavailable \
    gnome-tweaks gnome-extensions-app \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-blur-my-shell \
    gnome-shell-extension-forge
'

# ── Ghostty (COPR → dnf) ──
run_step "Ghostty" bash -c '
  echo "==> Installing Ghostty..."
  if command -v ghostty &>/dev/null; then
    echo "    Ghostty already installed"
  else
    sudo dnf copr enable -y pgdev/ghostty
    sudo dnf install -y ghostty
  fi
'

# ── Cider (Apple Music — repo → dnf) ──
run_step "Cider" bash -c '
  echo "==> Installing Cider..."
  if command -v cider &>/dev/null || rpm -q Cider &>/dev/null; then
    echo "    Cider already installed"
  else
    sudo rpm --import https://repo.cider.sh/RPM-GPG-KEY
    sudo tee /etc/yum.repos.d/cider.repo << '\''REPO'\'' >/dev/null
[cidercollective]
name=Cider Collective Repository
baseurl=https://repo.cider.sh/rpm/RPMS
enabled=1
gpgcheck=1
gpgkey=https://repo.cider.sh/RPM-GPG-KEY
REPO
    sudo dnf makecache
    sudo dnf install -y Cider
  fi
'

# ── Docker Engine (repo → dnf) ──
run_step "Docker" bash -c '
  echo "==> Installing Docker..."
  if command -v docker &>/dev/null; then
    echo "    Docker already installed"
  else
    sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
  fi
'

# ── Flatpak apps ──
run_step "Flatpak apps" bash -c '
  echo "==> Installing Flatpak apps..."
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

  FLATPAKS=(
    com.onepassword.OnePassword
    com.slack.Slack
    app.zen_browser.zen
    md.obsidian.Obsidian
    com.discordapp.Discord
    com.obsproject.Studio
    com.moonlight_stream.Moonlight
    net.davidotek.pupgui2
  )

  for app in "${FLATPAKS[@]}"; do
    if flatpak list --app 2>/dev/null | grep -q "$app"; then
      echo "    $app already installed"
    else
      flatpak install -y flathub "$app"
    fi
  done
'

# ── Cursor IDE (RPM) ──
run_step "Cursor IDE" bash -c '
  echo "==> Installing Cursor IDE..."
  if rpm -q cursor &>/dev/null; then
    echo "    Cursor already installed"
  else
    CURSOR_RPM="/tmp/cursor-latest.rpm"
    curl -fSL "https://api2.cursor.sh/updates/download/golden/linux-x64-rpm/cursor/latest" \
      -o "$CURSOR_RPM"
    sudo dnf install -y "$CURSOR_RPM"
    rm -f "$CURSOR_RPM"
  fi
'

# ── Helium Browser (AppImage from GitHub) ──
run_step "Helium Browser" bash -c '
  echo "==> Installing/updating Helium Browser..."
  HELIUM_VERSION_FILE="$HOME/Applications/.helium-version"
  HELIUM_LATEST=$(curl -fsSL https://api.github.com/repos/imputnet/helium-linux/releases/latest | jq -r ".tag_name")
  HELIUM_CURRENT=$(cat "$HELIUM_VERSION_FILE" 2>/dev/null || echo "")

  if [[ -n "$HELIUM_LATEST" && "$HELIUM_LATEST" != "$HELIUM_CURRENT" ]]; then
    mkdir -p "$HOME/Applications"
    HELIUM_URL="https://github.com/imputnet/helium-linux/releases/download/${HELIUM_LATEST}/helium-${HELIUM_LATEST}-x86_64.AppImage"
    echo "    Downloading Helium $HELIUM_LATEST..."
    curl -fSL "$HELIUM_URL" -o "$HOME/Applications/helium.AppImage"
    chmod +x "$HOME/Applications/helium.AppImage"
    echo "$HELIUM_LATEST" > "$HELIUM_VERSION_FILE"

    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/helium.desktop" << DESKTOP
[Desktop Entry]
Name=Helium Browser
Comment=Privacy-focused browser by imput
Exec=$HOME/Applications/helium.AppImage --no-sandbox %U
Icon=helium
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=x-scheme-handler/http;x-scheme-handler/https;text/html;
StartupWMClass=Helium
DESKTOP
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    echo "    Helium Browser $HELIUM_LATEST installed"
  elif [[ -n "$HELIUM_CURRENT" ]]; then
    echo "    Helium Browser $HELIUM_CURRENT is already latest"
  else
    echo "    ERROR: Could not fetch Helium version from GitHub"
    exit 1
  fi
'

# ── Claude Code CLI (requires Node via fnm) ──
run_step "Claude Code CLI" bash -c '
  echo "==> Installing Claude Code CLI..."
  if command -v claude &>/dev/null; then
    echo "    Claude CLI already installed"
  else
    if ! command -v fnm &>/dev/null; then
      echo "    ERROR: fnm not found — install Nix + Home Manager first (setup-nix.sh)"
      exit 1
    fi

    eval "$(fnm env)"
    if ! fnm list 2>/dev/null | grep -q lts-latest; then
      echo "    Installing Node LTS via fnm..."
      fnm install --lts || { echo "    ERROR: fnm install --lts failed"; exit 1; }
    fi
    fnm use --install-if-missing lts-latest || { echo "    ERROR: fnm use lts-latest failed"; exit 1; }

    if command -v node &>/dev/null; then
      curl -fsSL https://claude.ai/install.sh | sh || { echo "    ERROR: Claude Code install script failed"; exit 1; }
    else
      echo "    ERROR: node not available after fnm setup"
      exit 1
    fi
  fi
'

# ── waypaper (pipx) ──
run_step "waypaper" bash -c '
  echo "==> Installing waypaper..."
  if pipx list 2>/dev/null | grep -q waypaper; then
    echo "    waypaper already installed"
  else
    pipx install waypaper
  fi
'

echo ""
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "=== Fedora app installation complete (with errors) ==="
  echo ""
  echo "Failed steps:"
  for step in "${FAILED[@]}"; do
    echo "  - $step"
  done
  exit 1
else
  echo "=== Fedora app installation complete! ==="
fi

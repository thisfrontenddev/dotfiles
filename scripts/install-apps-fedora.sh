#!/usr/bin/env bash
set -euo pipefail

echo "=== Fedora App & Package Installation ==="

# ── System packages (dnf) ──
echo "==> Installing system packages..."
sudo dnf install -y --skip-unavailable \
  zsh git gcc gcc-c++ cmake ninja-build clang lld \
  golang java-latest-openjdk-devel \
  podman podman-compose \
  neovim tmux fzf \
  htop btop ripgrep fd-find bat jq yq \
  strace ltrace hyperfine tokei \
  fastfetch imagemagick ffmpeg \
  pipx snapper \
  fontconfig

# ── Sway ecosystem (dnf) ──
echo "==> Installing Sway ecosystem..."
sudo dnf install -y --skip-unavailable \
  sway waybar wofi mako swaybg swaylock swayidle \
  grim slurp wl-clipboard sway-systemd

# ── GNOME extras (dnf) ──
echo "==> Installing GNOME extras..."
sudo dnf install -y --skip-unavailable \
  gnome-tweaks gnome-extensions-app \
  gnome-shell-extension-appindicator \
  gnome-shell-extension-blur-my-shell \
  gnome-shell-extension-forge

# ── Ghostty (COPR → dnf) ──
echo "==> Installing Ghostty..."
if command -v ghostty &>/dev/null; then
  echo "    Ghostty already installed"
else
  sudo dnf copr enable -y pgdev/ghostty
  sudo dnf install -y ghostty
fi

# ── Docker Engine (repo → dnf) ──
echo "==> Installing Docker..."
if command -v docker &>/dev/null; then
  echo "    Docker already installed"
else
  sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
  sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER"
fi

# ── Flatpak apps ──
echo "==> Installing Flatpak apps..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

FLATPAKS=(
  com.onepassword.OnePassword
  com.slack.Slack
  app.zen_browser.zen
  md.obsidian.Obsidian
  com.spotify.Client
  com.discordapp.Discord
  com.obsproject.Studio
  com.figma.Figma
)

for app in "${FLATPAKS[@]}"; do
  if flatpak list --app 2>/dev/null | grep -q "$app"; then
    echo "    $app already installed"
  else
    flatpak install -y flathub "$app"
  fi
done

# ── Cursor IDE (AppImage) ──
echo "==> Installing Cursor IDE..."
if [[ -f "$HOME/Applications/cursor.AppImage" ]]; then
  echo "    Cursor already installed"
else
  mkdir -p "$HOME/Applications"
  curl -fSL "https://www.cursor.com/api/download?platform=linux-x86_64&releaseTrack=stable" \
    -o "$HOME/Applications/cursor.AppImage"
  chmod +x "$HOME/Applications/cursor.AppImage"

  mkdir -p "$HOME/.local/share/applications"
  cat > "$HOME/.local/share/applications/cursor.desktop" << DESKTOP
[Desktop Entry]
Name=Cursor
Comment=AI-powered code editor
Exec=$HOME/Applications/cursor.AppImage --no-sandbox %F
Icon=cursor
Terminal=false
Type=Application
Categories=Development;IDE;
MimeType=text/plain;
StartupWMClass=Cursor
DESKTOP
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

echo ""
echo "=== Fedora app installation complete! ==="

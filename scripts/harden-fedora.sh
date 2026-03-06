#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${GREEN}[✓] $1${NC}"; }
info() { echo -e "${YELLOW}    → $1${NC}"; }

echo "=== Fedora System Hardening ==="

# ── 1. Set hostname ──
step "Setting hostname"
CURRENT_HOSTNAME=$(hostnamectl --static 2>/dev/null || hostname)
if [[ "$CURRENT_HOSTNAME" == "blackwall" ]]; then
  info "Hostname already set to blackwall"
else
  sudo hostnamectl set-hostname blackwall
  info "Hostname set to blackwall"
fi

# ── 2. DNS-over-TLS (Cloudflare) ──
step "Configuring DNS-over-TLS (Cloudflare)"
DNS_CONF="/etc/systemd/resolved.conf.d/dns-over-tls.conf"
sudo mkdir -p /etc/systemd/resolved.conf.d
if [[ -f "$DNS_CONF" ]] && grep -q "cloudflare-dns.com" "$DNS_CONF"; then
  info "DNS-over-TLS already configured"
else
  sudo tee "$DNS_CONF" > /dev/null << 'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com
FallbackDNS=9.9.9.9#dns.quad9.net
DNSOverTLS=yes
DNSSEC=allow-downgrade
EOF
  sudo systemctl restart systemd-resolved
  info "DNS-over-TLS enabled with Cloudflare"
fi

# Tell NetworkManager to stop overriding per-link DNS
for conn in "Wired connection 1" "SFR_0020"; do
  if nmcli connection show "$conn" &>/dev/null; then
    CURRENT_DNS=$(nmcli -g ipv4.dns connection show "$conn")
    if [[ "$CURRENT_DNS" != "1.1.1.1,1.0.0.1" ]]; then
      sudo nmcli connection modify "$conn" ipv4.dns "1.1.1.1 1.0.0.1" ipv4.ignore-auto-dns yes
      info "DNS set for $conn"
    else
      info "DNS already set for $conn"
    fi
  fi
done

# ── 3. NVIDIA persistence mode ──
step "Enabling NVIDIA persistence mode"
if systemctl is-enabled nvidia-persistenced &>/dev/null; then
  info "nvidia-persistenced already enabled"
else
  sudo systemctl enable --now nvidia-persistenced
  info "nvidia-persistenced enabled"
fi

# ── 4. Snapper timers ──
step "Enabling Snapper snapshot timers"
sudo systemctl enable --now snapper-timeline.timer 2>/dev/null || true
sudo systemctl enable --now snapper-cleanup.timer 2>/dev/null || true
info "Snapper timeline + cleanup timers active"

# ── 5. Btrfs scrub timer ──
step "Enabling Btrfs scrub timer"
if [[ ! -f /etc/systemd/system/btrfs-scrub.timer ]]; then
  sudo tee /etc/systemd/system/btrfs-scrub.service > /dev/null << 'SCRUBSVC'
[Unit]
Description=Btrfs scrub on /

[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs scrub start -B /
SCRUBSVC
  sudo tee /etc/systemd/system/btrfs-scrub.timer > /dev/null << 'SCRUBTMR'
[Unit]
Description=Monthly Btrfs scrub on /

[Timer]
OnCalendar=monthly
Persistent=true
RandomizedDelaySec=1d

[Install]
WantedBy=timers.target
SCRUBTMR
  sudo systemctl daemon-reload
fi
sudo systemctl enable --now btrfs-scrub.timer 2>/dev/null || true
info "Btrfs monthly scrub enabled for /"

# ── 6. Sysctl tuning ──
step "Applying sysctl tuning"
SYSCTL_FILE="/etc/sysctl.d/99-dev-workstation.conf"
if [[ -f "$SYSCTL_FILE" ]] && grep -q "vm.swappiness" "$SYSCTL_FILE"; then
  info "Sysctl already tuned"
else
  sudo tee "$SYSCTL_FILE" > /dev/null << 'EOF'
# More responsive filesystem caching
vm.vfs_cache_pressure = 50
vm.dirty_bytes = 419430400
vm.dirty_background_bytes = 209715200
vm.swappiness = 10

# Increase inotify watches (IDEs, file watchers, hot reload)
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 512
fs.inotify.max_queued_events = 32768
EOF
  sudo sysctl --system > /dev/null
  info "Sysctl tuning applied"
fi

# ── 7. Disable WiFi autoconnect (ethernet preferred) ──
step "Disabling WiFi autoconnect"
if nmcli connection show "SFR_0020" &>/dev/null; then
  AUTOCONNECT=$(nmcli -g connection.autoconnect connection show "SFR_0020")
  if [[ "$AUTOCONNECT" == "yes" ]]; then
    nmcli connection modify "SFR_0020" connection.autoconnect no
    info "WiFi autoconnect disabled (ethernet preferred)"
  else
    info "WiFi autoconnect already disabled"
  fi
else
  info "No SFR_0020 WiFi profile found — skipping"
fi

# ── 8. Journald size limit ──
step "Setting journald size limit"
JOURNAL_CONF="/etc/systemd/journald.conf.d/size.conf"
sudo mkdir -p /etc/systemd/journald.conf.d
if [[ -f "$JOURNAL_CONF" ]]; then
  info "Journald size limit already configured"
else
  sudo tee "$JOURNAL_CONF" > /dev/null << 'EOF'
[Journal]
SystemMaxUse=500M
EOF
  sudo systemctl restart systemd-journald
  info "Journald capped at 500M"
fi

# ── 9. Automatic security updates ──
step "Enabling automatic security updates"
if ! rpm -q dnf5-plugin-automatic &>/dev/null; then
  sudo dnf install -y dnf5-plugin-automatic
fi
if [[ ! -f /etc/dnf/automatic.conf ]] || ! grep -q "upgrade_type = security" /etc/dnf/automatic.conf; then
  sudo tee /etc/dnf/automatic.conf > /dev/null << 'AUTOEOF'
[commands]
apply_updates = yes
upgrade_type = security
AUTOEOF
fi
sudo systemctl enable --now dnf5-automatic.timer 2>/dev/null || true
info "dnf5-automatic enabled (security updates only)"

# ── 10. Git commit signing (SSH key) ──
step "Configuring git commit signing"
if [[ "$(git config --global gpg.format 2>/dev/null)" == "ssh" ]]; then
  info "Git SSH signing already configured"
else
  git config --global gpg.format ssh
  git config --global user.signingkey ~/.ssh/id_ed25519.pub
  git config --global commit.gpgsign true
  info "Git commits will be signed with SSH key"
fi
# Upload signing key to GitHub (requires gh auth)
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  if ! gh ssh-key list 2>/dev/null | grep -q "signing"; then
    gh auth refresh -h github.com -s admin:ssh_signing_key 2>/dev/null || true
    gh ssh-key add ~/.ssh/id_ed25519.pub --type signing 2>/dev/null && \
      info "SSH signing key added to GitHub" || \
      info "Could not add SSH signing key to GitHub — add manually"
  else
    info "SSH signing key already on GitHub"
  fi
else
  info "gh not authenticated — add SSH signing key to GitHub manually"
fi

echo ""
echo "=== Fedora hardening complete! ==="

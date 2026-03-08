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

# ── 2. Firewall (strict zone) ──
step "Configuring firewall (ws-strict)"
sudo systemctl enable --now firewalld 2>/dev/null || true
CURRENT_ZONE=$(sudo firewall-cmd --get-default-zone)
if [[ "$CURRENT_ZONE" == "ws-strict" ]]; then
  info "ws-strict zone already active"
else
  # Create strict zone: only SSH + DHCPv6, no open high ports
  sudo firewall-cmd --permanent --new-zone=ws-strict 2>/dev/null || true
  sudo firewall-cmd --reload
  sudo firewall-cmd --permanent --zone=ws-strict --add-service=ssh 2>/dev/null || true
  sudo firewall-cmd --permanent --zone=ws-strict --add-service=dhcpv6-client 2>/dev/null || true
  sudo firewall-cmd --permanent --zone=ws-strict --set-target=default 2>/dev/null || true
  # Assign the primary network interface to the strict zone
  PRIMARY_IFACE=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
  if [[ -n "$PRIMARY_IFACE" ]]; then
    sudo firewall-cmd --permanent --zone=ws-strict --change-interface="$PRIMARY_IFACE"
  fi
  sudo firewall-cmd --set-default-zone=ws-strict
  sudo firewall-cmd --reload
  info "ws-strict zone created and activated (inbound: ssh + dhcpv6 only)"
fi

# ── 3. DNS-over-TLS (Cloudflare) ──
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

# Tell NetworkManager to stop overriding per-link DNS on active connections
while IFS= read -r conn; do
  [[ -z "$conn" ]] && continue
  CURRENT_DNS=$(nmcli -g ipv4.dns connection show "$conn" 2>/dev/null)
  if [[ "$CURRENT_DNS" != "1.1.1.1,1.0.0.1" ]]; then
    sudo nmcli connection modify "$conn" ipv4.dns "1.1.1.1 1.0.0.1" ipv4.ignore-auto-dns yes
    info "DNS set for $conn"
  else
    info "DNS already set for $conn"
  fi
done < <(nmcli -t -f NAME connection show --active 2>/dev/null)

# Install dispatcher script so future connections also get Cloudflare DNS
NM_DISPATCH="/etc/NetworkManager/dispatcher.d/99-cloudflare-dns"
if [[ -f "$NM_DISPATCH" ]]; then
  info "DNS dispatcher already installed"
else
  sudo tee "$NM_DISPATCH" > /dev/null << 'DISPATCH'
#!/usr/bin/env bash
# Enforce Cloudflare DNS on every new WiFi/ethernet connection
# Skip VPN and tunnel interfaces — they manage their own DNS
[[ "$2" != "up" ]] && exit 0
CONN="$CONNECTION_UUID"
[[ -z "$CONN" ]] && exit 0
CONN_TYPE=$(nmcli -g connection.type connection show uuid "$CONN" 2>/dev/null)
case "$CONN_TYPE" in
  vpn|wireguard|tun|*tunnel*) exit 0 ;;
esac
CURRENT_DNS=$(nmcli -g ipv4.dns connection show uuid "$CONN" 2>/dev/null)
if [[ "$CURRENT_DNS" != "1.1.1.1,1.0.0.1" ]]; then
  nmcli connection modify uuid "$CONN" ipv4.dns "1.1.1.1 1.0.0.1" ipv4.ignore-auto-dns yes
fi
DISPATCH
  sudo chmod 755 "$NM_DISPATCH"
  info "DNS dispatcher installed for future connections"
fi

# ── 4. NVIDIA persistence mode ──
step "Enabling NVIDIA persistence mode"
if systemctl is-enabled nvidia-persistenced &>/dev/null; then
  info "nvidia-persistenced already enabled"
else
  sudo systemctl enable --now nvidia-persistenced
  info "nvidia-persistenced enabled"
fi

# ── 5. NVIDIA fbdev in kernel cmdline ──
step "Ensuring nvidia-drm.fbdev=1 in kernel cmdline"
if grep -q "nvidia-drm.fbdev=1" /proc/cmdline; then
  info "nvidia-drm.fbdev=1 already in cmdline"
else
  sudo grubby --update-kernel=ALL --args="nvidia-drm.fbdev=1"
  info "nvidia-drm.fbdev=1 added (takes effect on next boot)"
fi

# ── 6. Disable CUPS (no printer needed) ──
step "Disabling CUPS printing service"
if systemctl is-active cups &>/dev/null; then
  sudo systemctl disable --now cups cups.socket cups.path 2>/dev/null || true
  info "CUPS disabled"
else
  info "CUPS already inactive"
fi

# ── 7. Snapper timers ──
step "Enabling Snapper snapshot timers"
sudo systemctl enable --now snapper-timeline.timer 2>/dev/null || true
sudo systemctl enable --now snapper-cleanup.timer 2>/dev/null || true
info "Snapper timeline + cleanup timers active"

# ── 8. Btrfs scrub timer ──
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

# ── 9. Sysctl tuning ──
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

# ── 10. Disable WiFi autoconnect (ethernet preferred) ──
step "Disabling WiFi autoconnect"
WIFI_DISABLED=false
while IFS= read -r wifi_conn; do
  [[ -z "$wifi_conn" ]] && continue
  AUTOCONNECT=$(nmcli -g connection.autoconnect connection show "$wifi_conn" 2>/dev/null)
  if [[ "$AUTOCONNECT" == "yes" ]]; then
    nmcli connection modify "$wifi_conn" connection.autoconnect no
    info "WiFi autoconnect disabled for $wifi_conn"
    WIFI_DISABLED=true
  fi
done < <(nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep ':802-11-wireless$' | cut -d: -f1)
if [[ "$WIFI_DISABLED" == "false" ]]; then
  info "No WiFi connections with autoconnect — skipping"
fi

# ── 11. Journald size limit ──
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

# ── 12. Automatic security updates ──
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

# ── 13. SSH key + Git commit signing ──
step "Ensuring SSH key exists"
SSH_KEY="$HOME/.ssh/id_ed25519"
if [[ -f "$SSH_KEY" ]]; then
  info "SSH key already exists at $SSH_KEY"
else
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  EMAIL=$(git config --global user.email 2>/dev/null || echo "")
  if [[ -z "$EMAIL" ]]; then
    read -rp "    Enter email for SSH key: " EMAIL
  fi
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$SSH_KEY" -N ""
  info "SSH key generated at $SSH_KEY"
  eval "$(ssh-agent -s)" >/dev/null 2>&1
  ssh-add "$SSH_KEY" 2>/dev/null || true
  info "Key added to ssh-agent"
fi

step "Configuring git commit signing"
if [[ "$(git config --global gpg.format 2>/dev/null)" == "ssh" ]]; then
  info "Git SSH signing already configured"
else
  git config --global gpg.format ssh
  git config --global user.signingkey "${SSH_KEY}.pub"
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
# Set up allowed_signers for signature verification
SIGNERS_FILE="$HOME/.config/git/allowed_signers"
if [[ -f "$SIGNERS_FILE" ]]; then
  info "allowed_signers already exists"
else
  mkdir -p "$HOME/.config/git"
  EMAIL=$(git config --global user.email)
  echo "$EMAIL $(cat ~/.ssh/id_ed25519.pub)" > "$SIGNERS_FILE"
  git config --global gpg.ssh.allowedSignersFile "$SIGNERS_FILE"
  info "allowed_signers created for $EMAIL"
fi

# ── 14. Flatpak auto-update timer ──
step "Enabling Flatpak auto-update"
FLATPAK_SERVICE="$HOME/.config/systemd/user/flatpak-update.service"
FLATPAK_TIMER="$HOME/.config/systemd/user/flatpak-update.timer"
if [[ -f "$FLATPAK_TIMER" ]]; then
  info "Flatpak auto-update timer already exists"
else
  mkdir -p "$HOME/.config/systemd/user"
  cat > "$FLATPAK_SERVICE" << 'EOF'
[Unit]
Description=Update Flatpak apps

[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak update -y --noninteractive
EOF
  cat > "$FLATPAK_TIMER" << 'EOF'
[Unit]
Description=Weekly Flatpak update

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now flatpak-update.timer
  info "Flatpak weekly auto-update enabled"
fi

# ── 15. fail2ban (SSH brute-force protection) ──
step "Configuring fail2ban"
if ! rpm -q fail2ban &>/dev/null; then
  sudo dnf install -y fail2ban
fi
JAIL_LOCAL="/etc/fail2ban/jail.local"
if [[ -f "$JAIL_LOCAL" ]]; then
  info "fail2ban jail.local already configured"
else
  sudo tee "$JAIL_LOCAL" > /dev/null << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
EOF
  info "fail2ban jail.local created (5 attempts / 10min → 1h ban)"
fi
sudo systemctl enable fail2ban
# Only start if sshd is active — otherwise it just sits ready
if systemctl is-active sshd &>/dev/null; then
  sudo systemctl start fail2ban
  info "fail2ban started (sshd is running)"
else
  info "fail2ban enabled but not started (sshd is inactive)"
fi

# ── 16. Disable fingerprint auth (no reader on desktop) ──
step "Disabling fingerprint PAM"
if authselect current 2>/dev/null | grep -q "with-fingerprint"; then
  sudo authselect disable-feature with-fingerprint
  info "Fingerprint auth disabled"
else
  info "Fingerprint auth already disabled"
fi


echo ""
echo "=== Fedora hardening complete! ==="

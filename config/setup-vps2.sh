#!/bin/bash
# Jalankan script ini di VPS KEDUA (bukan VPS utama)
# Fungsi: Buat systemd service untuk SSH tunnel ke VPS utama (IP)

set -e

read -p " Input IP VPS Utama : " VPS_UTAMA

TUNNEL_PORT=2026
TARGET_PORT=2009
SSH_USER="root"

echo "=== Setup SSH Tunnel Systemd Service ==="
echo "VPS Utama: $VPS_UTAMA"
echo "Tunnel: localhost:$TUNNEL_PORT -> $VPS_UTAMA:$TARGET_PORT"
echo ""

# 1. Install autossh
apt-get update && apt-get install -y autossh

# 2. Generate SSH key jika belum ada
[ -f /root/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ""
echo ""
echo "=== COPY PUBLIC KEY INI KE VPS UTAMA ==="
cat /root/.ssh/id_ed25519.pub
echo ""
echo "Di VPS utama, jalankan:"
echo "  mkdir -p /root/.ssh"
echo "  echo '$(cat /root/.ssh/id_ed25519.pub)' >> /root/.ssh/authorized_keys"
echo "  chmod 600 /root/.ssh/authorized_keys"
echo ""
read -p "Sudah copy ke VPS utama? Tekan Enter untuk lanjut..."

# 3. Test koneksi
echo "Test koneksi SSH..."
ssh -o ConnectTimeout=10 -o BatchMode=yes $SSH_USER@$VPS_UTAMA exit && echo "✅ Koneksi OK" || { echo "❌ Gagal koneksi"; exit 1; }

# 4. Buat systemd service
cat > /etc/systemd/system/ssh-tunnel-admin.service << SVC
[Unit]
Description=SSH Tunnel to Admin Panel (VPS Utama)
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Environment="AUTOSSH_GATETIME=0"
Environment="AUTOSSH_POLL=30"
Environment="AUTOSSH_FIRST_POLL=30"
Environment="AUTOSSH_DEBUG=1"
ExecStart=/usr/bin/autossh -M 0 -N \
  -o "ServerAliveInterval=30" \
  -o "ServerAliveCountMax=3" \
  -o "ExitOnForwardFailure=yes" \
  -o "StrictHostKeyChecking=no" \
  -o "UserKnownHostsFile=/dev/null" \
  -L 0.0.0.0:$TUNNEL_PORT:127.0.0.1:$TARGET_PORT \
  $SSH_USER@$VPS_UTAMA
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVC

# 5. Enable & start
systemctl daemon-reload
systemctl enable ssh-tunnel-admin
systemctl restart ssh-tunnel-admin

echo ""
echo "=== SELESAI ==="
echo "Status: systemctl status ssh-tunnel-admin"
echo "Logs: journalctl -u ssh-tunnel-admin -f"
echo ""
echo "Di VPS kedua, akses admin panel via:"
echo "  http://localhost:$TUNNEL_PORT/admin/login"
echo ""
echo "Atau dari laptop via VMess -> VPS kedua -> localhost:$TUNNEL_PORT"

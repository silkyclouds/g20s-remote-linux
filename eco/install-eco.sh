#!/usr/bin/env bash
# Optional: install g20-eco as a root systemd service (idle power saving, never suspends). Run with sudo.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo:  sudo ./eco/install-eco.sh"; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)
install -m 755 "$here/g20-eco" /usr/local/bin/g20-eco
cat > /etc/systemd/system/g20-eco.service <<'UNIT'
[Unit]
Description=Idle power saving (CPU), full speed on activity

[Service]
ExecStart=/usr/local/bin/g20-eco
Restart=always
RestartSec=5
Nice=10

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload; systemctl enable g20-eco.service; systemctl restart g20-eco.service
echo "g20-eco running. State: cat /run/g20-eco.state   Stop and restore: sudo systemctl stop g20-eco"

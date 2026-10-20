#!/usr/bin/env bash
# User part (no sudo): scripts, services, app switcher. Run install-system.sh with sudo separately.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
BIN=$HOME/.local/bin; UNITS=$HOME/.config/systemd/user; SW=$HOME/.local/share/g20-switcher; LIBX=$HOME/.local/libexec/g20
mkdir -p "$BIN" "$UNITS" "$SW" "$LIBX" "$HOME/.config/g20" "$HOME/.local/share/applications"
for f in g20d g20-home g20-window g20-micro g20-micro-kwin g20-switcher g20-capture; do install -m 755 "$here/bin/$f" "$BIN/$f"; done
install -m 755 "$here/switcher/g20-switcher-server" "$BIN/g20-switcher-server"
install -m 644 "$here/switcher/index.html" "$SW/index.html"
# The switcher takes window screenshots through KWin's ScreenShot2, which KWin only allows for programs declared in a .desktop file.
# We give it a private copy of the Python interpreter so that authorization is not granted to every Python script you run.
PY=$(readlink -f "$(command -v python3)"); PYHOME=$(dirname "$(dirname "$PY")")
cp "$PY" "$LIBX/python3"; chmod 755 "$LIBX/python3"
REAL=$(readlink -f "$LIBX/python3")
cat > "$HOME/.local/share/applications/g20-switcher-shot.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=G20 switcher (window thumbnails)
Exec=$REAL %f
NoDisplay=true
Terminal=false
X-KDE-DBUS-Restricted-Interfaces=org.kde.KWin.ScreenShot2
DESK
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true
for u in g20d.service ydotoold.service "g20-micro@.service"; do install -m 644 "$here/systemd/$u" "$UNITS/$u"; done
sed "s|@PYTHONHOME@|$PYHOME|" "$here/systemd/g20-switcher.service" > "$UNITS/g20-switcher.service"
[ -f "$HOME/.config/g20/g20.conf" ] || cat > "$HOME/.config/g20/g20.conf" <<'CONF'
# G20 remote configuration (KEY=VALUE). Keep this file private (chmod 600): it may hold your webhook URL.
# TV actions: a Home Assistant webhook ...
#G20_HA_WEBHOOK_URL=http://homeassistant.local:8123/api/webhook/YOUR_LONG_RANDOM_ID
# ... or any shell command per action (HDMI-CEC, IR blaster, ...):
#G20_CMD_POWER=cec-client ...
# Home button: the app to raise (window class substring), its process name and its start command.
#G20_HOME_MATCH=plezy
#G20_HOME_PROC=plezy
#G20_HOME_CMD=plezy
CONF
chmod 600 "$HOME/.config/g20/g20.conf"
systemctl --user daemon-reload
systemctl --user enable --now ydotoold.service g20d.service g20-switcher.service
loginctl enable-linger "$USER" 2>/dev/null || true
echo "User part installed. If not done yet:  sudo ./install-system.sh   (then replug the dongle)"

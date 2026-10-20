#!/usr/bin/env bash
# G20S remote on Linux: installs everything in your home directory, then runs the first-run wizard (needs sudo for the key remap).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
BIN=$HOME/.local/bin; UNITS=$HOME/.config/systemd/user; SW=$HOME/.local/share/g20-switcher; LIBX=$HOME/.local/libexec/g20
mkdir -p "$BIN" "$UNITS" "$SW" "$LIBX" "$HOME/.config/g20" "$HOME/.local/share/applications"


echo "== checking what this computer has"
missing_hard=""; missing_soft=""
need() { command -v "$1" >/dev/null 2>&1 || missing_hard="$missing_hard $1"; }
want() { command -v "$1" >/dev/null 2>&1 || missing_soft="$missing_soft $1"; }
need python3; need systemctl; need curl; need busctl
command -v qdbus >/dev/null 2>&1 || command -v qdbus6 >/dev/null 2>&1 || missing_hard="$missing_hard qdbus"
want ydotool; want wl-copy; want pw-dump; want kscreen-doctor
python3 -c "import gi" 2>/dev/null || missing_soft="$missing_soft python3-gobject(gi)"
python3 -c "import PySide6.QtWebEngineQuick" 2>/dev/null || missing_soft="$missing_soft PySide6+QtWebEngine(on-screen-notices)"
command -v google-chrome-stable >/dev/null 2>&1 || command -v chromium >/dev/null 2>&1 || command -v google-chrome >/dev/null 2>&1 || flatpak list 2>/dev/null | grep -qiE "chrom" || missing_soft="$missing_soft chrome-or-chromium(switcher-and-keyboard-pages)"
if [ -n "$missing_hard" ]; then
  echo "MISSING (required):$missing_hard"
  echo "  Fedora / Bazzite: these come with the base system (qdbus is in qt6-qttools). Debian / Ubuntu: sudo apt install python3 curl systemd qt6-tools-dev-tools"
  echo "  Install them, then run ./install.sh again."; exit 1
fi
[ -n "$missing_soft" ] && { echo "Missing (optional, the matching feature is skipped or limited):$missing_soft"
  echo "  Bazzite / Fedora Atomic: flatpak install flathub com.google.Chrome ; ydotool and wl-clipboard are usually present (else: brew install ydotool wl-clipboard)"
  echo "  Debian / Ubuntu: sudo apt install ydotool wl-clipboard python3-gi python3-pyside6.qtwebengine pipewire-bin kscreen"; echo; }
if [ "${XDG_SESSION_TYPE:-}" != "wayland" ]; then echo "Note: this session is not Wayland (${XDG_SESSION_TYPE:-unknown}). The window scripts and the notices need KDE Plasma on Wayland."; fi

echo "== scripts and services"
for f in g20d g20-home g20-window g20-micro g20-micro-kwin g20-switcher g20-source g20-capture g20-setup g20-audio-watch g20-audio-setup g20-toast; do install -m 755 "$here/bin/$f" "$BIN/$f"; done
install -m 755 "$here/switcher/g20-switcher-server" "$BIN/g20-switcher-server"
install -m 644 "$here/switcher/index.html" "$SW/index.html"
mkdir -p "$SW/logos" "$HOME/.config/g20/logos"; cp "$here"/logos/* "$SW/logos/"
for pg in keyboard.html sources.html audio.html notice.html; do [ -f "$here/switcher/$pg" ] && install -m 644 "$here/switcher/$pg" "$SW/$pg"; done

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
for u in g20d.service ydotoold.service g20-audio-watch.service "g20-micro@.service" "g20-toast@.service"; do install -m 644 "$here/systemd/$u" "$UNITS/$u"; done
sed "s|@PYTHONHOME@|$PYHOME|" "$here/systemd/g20-switcher.service" > "$UNITS/g20-switcher.service"
[ -f "$HOME/.config/g20/g20.conf" ] || : > "$HOME/.config/g20/g20.conf"
chmod 600 "$HOME/.config/g20/g20.conf"
loginctl enable-linger "$USER" 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable --now ydotoold.service g20-switcher.service g20-audio-watch.service

echo; echo "== first-run wizard (sudo password needed to install the key remap)"
sudo "$here/bin/g20-setup"
systemctl --user enable --now g20d.service
systemctl --user restart g20d.service

echo
read -r -p "Set up VOICE search now (needs a Bluetooth voice remote and adapter)? [y/N] " v || v=n
case "$v" in [yY]*) "$here/voice/install-voice.sh" ;; esac
echo "Done. Replug the dongle (or reconnect the remote) if you have not yet, then try the buttons."

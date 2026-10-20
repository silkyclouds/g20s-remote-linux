#!/usr/bin/env bash
# System part (run with sudo, once): remap the remote's keys and let your user read it. Then UNPLUG AND REPLUG THE DONGLE.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo:  sudo ./install-system.sh"; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)
install -m 644 "$here/hwdb/61-g20s-remote.hwdb" /etc/udev/hwdb.d/61-g20s-remote.hwdb
install -m 644 "$here/udev/62-g20s-remote.rules" /etc/udev/rules.d/62-g20s-remote.rules
systemd-hwdb update
udevadm control --reload
echo "Done. Now unplug the USB dongle for a second and plug it back in."

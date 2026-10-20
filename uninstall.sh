#!/usr/bin/env bash
systemctl --user disable --now g20d.service g20-switcher.service ydotoold.service 2>/dev/null
rm -f ~/.local/bin/g20d ~/.local/bin/g20-{home,window,micro,micro-kwin,switcher,capture,switcher-server}
rm -rf ~/.local/share/g20-switcher ~/.local/libexec/g20 ~/.local/share/applications/g20-switcher-shot.desktop
rm -f ~/.config/systemd/user/{g20d,ydotoold,g20-switcher}.service ~/.config/systemd/user/g20-micro@.service
echo "User part removed. System part:  sudo rm /etc/udev/hwdb.d/61-g20s-remote.hwdb /etc/udev/rules.d/62-g20s-remote.rules && sudo systemd-hwdb update"

#!/usr/bin/env bash
systemctl --user disable --now g20d.service g20-switcher.service ydotoold.service g20-audio-watch.service g20-toast@notice.service g20-toast@audio.service g20-voice.service atvvoice.service 2>/dev/null
rm -f ~/.local/bin/g20d ~/.local/bin/g20-{home,window,micro,micro-kwin,switcher,capture,setup,switcher-server,voice,audio-watch,audio-setup,toast} ~/.local/bin/atvvoice
rm -rf ~/.local/share/g20-switcher ~/.local/share/g20-voice ~/.local/libexec/g20 ~/.local/share/applications/g20-switcher-shot.desktop
rm -f ~/.config/systemd/user/{g20d,ydotoold,g20-switcher,g20-voice,g20-audio-watch,atvvoice}.service ~/.config/systemd/user/g20-micro@.service ~/.config/systemd/user/g20-toast@.service
echo "User part removed. System part:  sudo rm -f /etc/udev/hwdb.d/61-g20-remote.hwdb /etc/udev/rules.d/62-g20-remote.rules && sudo systemd-hwdb update"

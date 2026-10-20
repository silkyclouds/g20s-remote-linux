# G20S remote on Linux: replace your Nvidia Shield with your PC

![App switcher](docs/app-switcher.png)

## Why this exists

Like a lot of people, my **Nvidia Shield** became slow and laggy over the years, especially with 4K content. It does not play
**AV1** well, and moving through its menus got tedious. So I decided to use the machine I already had: my **gaming PC**, put in a
low-energy mode, doing everything on the TV: **Steam in Big Picture**, a **Plex** client (I chose [Plezy](https://github.com/edde746/plezy);
a Jellyfin client works the same way) and a **YouTube** client ([VacuumTube](https://github.com/shy1132/VacuumTube)).

That left one problem: a remote. I settled on the **JZK G20S Pro Plus** because it is **backlit**, has a **microphone**, **programmable
number keys**, an **air mouse**, and it can control the TV: the remote itself learns infrared for Power and Mute, and I send power and
**volume** to the TV through **Home Assistant** (Samsung / SmartThings integrations) so the PC stays the single hub and the volume
keys change the **TV's** volume instead of the PC's. This repository is everything needed to make that remote a proper
couch controller on Linux, and to make it **plug and play** for anyone with a similar remote (any brand: you teach it your buttons).

Result: no more Shield lag, 4K and AV1 play fine on the PC, the PC drops to a low-power state when nobody uses it, and the
remote does everything from the sofa.

## What you get

* **Power / Volume / Mute** go to the **TV** (Home Assistant webhook, or any command you like), not to the PC. The PC never suspends because of the Power key.
* **Home** brings your media app back full screen (or starts it).
* **Source** opens a **TV input picker** (HDMI 1, 2, 3...) and switches the TV's input.
* **D-pad, OK, Back** work everywhere, including **Steam Big Picture** (Back becomes Escape, which is what Steam wants).
* **Play/Pause, Rewind/Previous, Fast-forward/Next** act on the player (standard media keys, MPRIS).
* **Search key**: opens a **TV on-screen keyboard** (D-pad or air mouse, letters, numbers, symbols, accents, AZERTY/QWERTY/QWERTZ).
* **Voice search** if the remote is paired over **Bluetooth**: hold the mic key and speak, in the language(s) you choose (e.g. French and English); the text lands in the keyboard's field.
* Optional buttons: **app switcher** (a TV-style card view of the open windows with live screenshots; hold OK to kill a frozen app), previous / next window.
* An optional **scene button**: one press starts a Home Assistant scene (e.g. "Movie time") and a notice slides in at the top right of the screen for 5 seconds (green when it worked, amber if Home Assistant did not answer). Map it with `sudo g20-setup --only scene`; see [ha/scene.example.yaml](ha/scene.example.yaml).
* A **"maximum quality" checklist** toast when a film starts (is the sound an untouched bitstream, which codec, lossless or not, channels, rate, screen mode), plus `g20-audio-setup` to make PipeWire pass TrueHD / DTS-HD / Dolby Digital to your soundbar. See [docs/media-center.md](docs/media-center.md).
* Optional **idle power saving** (`g20-eco`): the PC stays awake and ready but uses the minimum when nothing needs it.

## Quick start

```bash
git clone https://github.com/silkyclouds/g20s-remote-linux && cd g20s-remote-linux
./install.sh
```

`install.sh` installs everything in your home directory, then runs a **first-run wizard** (it asks for your `sudo` password for the key remap):

1. *Press any button on your remote.* It is identified (2.4 GHz dongle or Bluetooth, any brand).
2. For every function it asks you to **press the matching button**: Up, Down, Left, Right, OK, Back, Home, Power, Volume +, Volume -, Mute, Mic/Search,
   Play/Pause, Rewind, Fast-forward, and the **Source** button, the **app switcher** and previous/next window. **No such button? Press Escape on your keyboard** (in the terminal) to skip it.
3. It writes the remap, then asks (optional) for your Home Assistant webhook and your voice languages.
4. **Unplug and replug the dongle** (or reconnect the Bluetooth remote) once, and you are done.

If you own the **JZK G20S Pro Plus with its dongle**, the wizard recognises it and offers the tested mapping in one keypress.

The functions are fixed on purpose, so every remote ends up behaving the same way (table below). Rerun the wizard any time: `sudo bin/g20-setup`.

## The functions

You choose which button of **your** remote does each function (the wizard asks); the functions themselves are fixed, so every remote behaves the same way.

| Function | What the PC sees after the remap | What it does |
|---|---|---|
| Up / Down / Left / Right | arrow keys | navigation |
| OK | Enter | select |
| Back | Escape | back |
| Home | `KEY_MACRO1` | raise (or start) your home app, full screen |
| Power | `KEY_PROG1` | toggle the **TV**, and pause any playing media |
| Volume + / - | `KEY_PROG2` / `KEY_PROG3` | **TV** volume (repeats while held) |
| Mute | `KEY_PROG4` | **TV** mute |
| Mic / Search *(optional)* | `KEY_VOICECOMMAND` | on-screen keyboard (+ voice when set up) |
| Play/Pause, Rewind/Previous, Fast-forward/Next | media keys | player control |
| **Source** *(optional)* | `KEY_MACRO5` | **TV input picker** (HDMI 1, 2, 3...): choose with the D-pad, the TV switches through Home Assistant; press again to close |
| **App switcher** *(optional)* | `KEY_MACRO3` | cards of the open windows, with screenshots; press again to close (or raise it if it is behind); never two |
| Previous / next window *(optional)* | `KEY_MACRO2` / `KEY_MACRO4` | like Alt+Tab |
| **Scene** *(optional)* | `KEY_MACRO6` | runs your Home Assistant scene or command, then shows a 5 s notice at the top right (see below) |

`KEY_PROG*` and `KEY_MACRO*` are keys no desktop binds (`F13` would open Quick Settings on KDE), so nothing reacts to them except `g20d`.
Redo the whole mapping with `sudo bin/g20-setup`, or only some functions with `sudo bin/g20-setup --only source,switcher`
(the others keep their button). Names of the functions: `up down left right ok back home power volup voldown mute mic play prev next source switcher prevwin nextwin scene`.

For reference, the tested **G20S Pro Plus dongle** preset (scancode → function): OK `0xc0041`, Back `0xc0224`, Home `0xc0223`, Power `0x10081`,
Vol+ `0xc00e9`, Vol- `0xc00ea`, Mute `0xc00e2`, Mic `0xc00cf`, Play `0xc00cd`, Pg+ `0x7004b` (source), keys 1/2/3 `0x7001e` / `0x7001f` / `0x70020`
(previous window / app switcher / next window).

## The TV input picker

![TV input picker](docs/source-picker.png)

Press your **Source** button: one card per HDMI input, the current one badged. **Left/right** and **OK** (or the air mouse); the TV switches through the
Home Assistant webhook (`media_player.select_source`, see `ha/automation.example.yaml`) or your own command (`G20_CMD_SOURCE`, the id is in `$G20_SOURCE`).
**When the TV is not on the PC's input** you cannot see the picker. With `G20_SOURCE_VIA_HA=1`, Home Assistant tells the PC which input the TV is on: if it is the PC's (`G20_PC_INPUT`, default `hdmi4`), the picker opens; if not, **each press selects the next input blindly** (the TV shows its own banner), until you are back on the PC. See `ha/automation.example.yaml`.
Declare your inputs in `~/.config/g20/g20.conf` (the wizard asks): `G20_SOURCES=hdmi1:Shield,hdmi2:PC,hdmi3:PlayStation,hdmi4`
(ids must match your TV integration's source names; the label is optional).

## The app switcher

Press your **app switcher** button: a full-screen page lists every open window as a card with a live screenshot, the app icon and the title.
**Left/right** move, **OK** brings the window to the front, **hold OK for 3 seconds** kills the app (SIGTERM, then SIGKILL; Steam is relaunched in Big Picture),
**Back** or the same button again closes it. The page is a single HTML file designed with [Claude Design](https://claude.ai/design) and served unmodified;
a small local server lists windows through a KWin script (called back over D-Bus) and takes the screenshots with KWin's `ScreenShot2`.

## The on-screen keyboard and voice

![On-screen keyboard](docs/keyboard.png)

Press the **Mic/Search** key: a keyboard opens (D-pad + OK, or the air-mouse pointer; hold OK on a letter for accents).
Type, press **Search**: the text is pasted into the app that had the focus (for Plezy, the search page is opened first) and Enter is sent.

**Voice** needs a **Bluetooth** remote and a Bluetooth adapter: the microphone of this remote type only works over Bluetooth
(Android TV voice protocol), never through the 2.4 GHz dongle, and the remote is in one mode or the other, not both. Install it with
`./voice/install-voice.sh`, pair the remote once with `bluetoothctl`, rerun `sudo bin/g20-setup` (the Bluetooth device has other ids), and hold the mic key:
the transcript fills the keyboard's field and you can correct it before searching.
It uses [ATVVoice](https://github.com/b0o/ATVVoice) (the remote's mic as a PipeWire source) and [faster-whisper](https://github.com/SYSTRAN/faster-whisper)
(GPU if you have an NVIDIA card, CPU otherwise). **Languages**: set `G20_VOICE_LANGS=fr,en` (first = default); with several languages the spoken language is
detected **among those only**, so a family can ask for an English title one moment and a French one the next.

## The scene button

`sudo ./bin/g20-setup --only scene` asks you to press the remote button you want, then the name shown in the notice and the Home Assistant webhook (or any shell command) that starts the scene.
The result is also shown on screen: `Movie time - Scene started`, or in amber `Home Assistant did not answer`. The same notice can be triggered by Home Assistant when the scene is started from a Zigbee button
or the dashboard (`/api/remote/notice`, secret + IP guarded, see `ha/scene.example.yaml`). Settings: `G20_SCENE_LABEL`, `G20_SCENE_WEBHOOK_URL` or `G20_CMD_SCENE`, `G20_SCENE_ICON` (scene, light, info).
The notice page (`switcher/notice.html`, designed with Claude Design like the other pages) is a 1920x1080 canvas shown in a transparent window over the whole screen for 5 s; without it the result is only logged (`journalctl --user -u g20d`).

## Media center: bit-perfect sound and the quality checklist

A PC behind a soundbar or AV receiver can send TrueHD, DTS-HD and Dolby Digital untouched, and prove it. `g20-audio-setup` reports and (with `--apply`) enables the passthrough codecs your HDMI output announces;
`g20-audio-watch` reads the real stream when a film starts and the switcher shows a short checklist. The full, verified method (with what cannot be verified) is in [docs/media-center.md](docs/media-center.md).

## Requirements

KDE Plasma 6 on **Wayland** (window scripts use KWin), systemd user services, `qdbus`, `curl`, `busctl`, Python 3.11+ with PyGObject (`gi`) and Pillow,
`ydotool`/`ydotoold` and `wl-clipboard` (keyboard / search), Chrome or Chromium (native or Flatpak) for the switcher and keyboard.
Tested on **Bazzite** (Fedora Atomic) with Plasma 6.7, a 4K TV, Steam Big Picture, Plezy and VacuumTube. Nothing needs `rpm-ostree` layering:
PipeWire (`pw-dump`, `pw-cli`, `pactl`) for the audio part. Everything lives in `~/.local`, `~/.config` and two files in `/etc/udev`.

## Configuration

`~/.config/g20/g20.conf` (private, `chmod 600`):

```ini
G20_DEVICE_IDS=4842:0001                 # set by the wizard
G20_HA_WEBHOOK_URL=http://homeassistant.local:8123/api/webhook/YOUR_LONG_RANDOM_ID
#G20_CMD_POWER=...                       # or your own command per action (HDMI-CEC, IR blaster...)
G20_HOME_MATCH=plezy                     # window class of your home app, its process name and start command
G20_HOME_PROC=plezy
G20_HOME_CMD=plezy
G20_KEYBOARD_LAYOUT=qwerty               # qwerty | azerty | qwertz
G20_SOURCES=hdmi1,hdmi2:PC,hdmi3,hdmi4   # TV inputs for the source picker (id:label)
G20_VOICE_LANGS=fr,en                    # voice languages, first = default
G20_VOICE_MODEL=small                    # tiny | base | small | medium | large-v3
```

Home Assistant side: `ha/automation.example.yaml` receives the webhook; `ha/power-with-soundbar.example.yaml` is the Power sequence when the PC sits behind a soundbar (Power toggles using a power-measuring plug on the TV, because many TV integrations report a stale state).

## Optional: idle power saving

`sudo ./eco/install-eco.sh`: after 90 s without video playback, game, emulator or inference (a local Ollama keeps answering), the CPU goes to its
lowest energy profile with turbo off; it goes back at the first activity. No suspend, no service stopped. AMD `amd-pstate-epp` / Intel EPP.

## Troubleshooting

* A key still does the old thing: the dongle was not replugged after the wizard.
* `/dev/input/eventNN` numbers change at every replug; nothing here depends on them.
* Nothing on a key: `journalctl --user -u g20d -f`. Switcher without screenshots: `journalctl --user -u g20-switcher`.
* Steam's own screensaver is not woken by this remote: disable it in Steam (Settings > Customization > Screensaver).
* Uninstall: `./uninstall.sh`.

MIT licence. Not affiliated with any of the projects mentioned.

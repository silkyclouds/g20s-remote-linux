# Turn a Linux PC into a real media center (picture, sound, remote)

Everything below was verified on **Bazzite** (Fedora Atomic, KDE Plasma 6.7 Wayland, NVIDIA RTX 3090 and an AMD APU), a **Samsung HW-Q800B soundbar**
between the PC and a Samsung Q60R TV, PipeWire 1.6. What could not be verified is said so.

## 1. The chain and what limits it

PC -> soundbar HDMI in -> soundbar HDMI out -> TV. The PC reads the **soundbar's EDID**, not the TV's: the soundbar decides what the PC may send.
Read it, it answers most questions:

```bash
for c in /sys/class/drm/card*-HDMI-A-*/edid; do [ -s $c ] && echo $c && edid-decode $c | grep -iE "Maximum TMDS|ST2084|HLG|Dolby|DTS|MLP|Linear PCM|Short Audio|VIC 97|ALLM"; done
```

For this soundbar: 4K60 at 8 bits RGB (its 600 MHz TMDS limit; 10/12 bits only as 4:2:0), HDR10/HLG/HDR10+ accepted, ALLM announced, LPCM 8 ch up to 192 kHz,
Dolby TrueHD, E-AC-3 (with the Atmos object extension), AC-3, DTS and DTS-HD. A soundbar or receiver with other limits changes the picture, not the method.

## 2. Lossless sound: bitstream to the soundbar

By default PipeWire folds everything to stereo PCM and only offers AC-3 / E-AC-3 on the HDMI route. `bin/g20-audio-setup` reports what your HDMI output announces and
what it would change; `--apply` enables every announced codec on the route (saved by WirePlumber, no root) and, with `--profile surround71`, switches the card to 7.1 so multichannel PCM is not folded:

```bash
g20-audio-setup --profile surround71            # report only
g20-audio-setup --profile surround71 --apply    # do it
```

Then enable passthrough in the player (Plezy: Settings > Audio > Passthrough; mpv: `audio-spdif=ac3,eac3,dts,dts-hd,truehd`).

**Proof, not trust.** While a film plays, the real format on the wire is in `/proc`:

```bash
grep -H . /proc/asound/card*/pcm*p/sub0/hw_params
# TrueHD   -> rate: 192000, channels: 8     (HBR transport)
# AC-3/DTS -> rate: 48000, channels: 2      (IEC 61937 framing, the bar decodes it)
# E-AC-3   -> rate: 192000, channels: 2
# PCM 5.1  -> S32_LE, channels: 8, rate: 48000
```

What the PC cannot prove: the layout inside a bitstream and **Dolby Atmos objects** are only visible on your soundbar's own display or app. Do not trust a PC-side label for those.

## 3. The "maximum quality" checklist (toast)

`g20-audio-watch` notices when an HDMI playback starts and reads the PipeWire stream that feeds it: untouched bitstream or decoded PCM, which codec, channels and rate,
whether the player volume is at 100 %, and the screen mode. `g20-switcher-server` turns that into a small checklist card shown for a few seconds over the video
(page `audio.html`, designed with Claude Design). Only media players listed in `G20_AUDIO_POPUP_APPS` trigger it; `G20_AUDIO_POPUP=0` disables it.
Without `audio.html` the result is simply logged: `journalctl --user -u g20-audio-watch`.

## 4. Picture

* 4K60 8-bit RGB is the ceiling behind this soundbar. The NVIDIA driver exposes neither `max bpc` nor the RGB range; Plasma's HDR needs a source that can do 10-bit.
* Wide Color Gamut can make the connector announce `Colorspace=BT2020_RGB` while the desktop is SDR (read it with the DRM property list). We turned it off
  (`kscreen-doctor output.<name>.wcg.disable`) to rule out washed-out colours; we have not proven it was the cause.
* The TV's Game Mode is not reachable from SmartThings on the Q60R (no capability). The soundbar announces ALLM, which can switch it automatically for games on supporting TVs.

## 5. Remote, TV and Home Assistant

The remote part is the rest of this project. The soundbar-aware Power sequence (soundbar first, then TV, then the right input) is in
`ha/power-with-soundbar.example.yaml`; the **Source** key opens a picker when the TV is on the PC and cycles inputs blindly otherwise.

## 6. Not possible from software (checked)

The Samsung HW-Q800B exposes no rear-speaker or woofer level through SmartThings (the `execute` endpoints for `surroundspeaker`, `channelVolume`, `woofer`,
`soundmode`, `advancedaudio` and `eq` answer with empty data, and the available integrations only do power, volume, mute and source). Those are set on the soundbar's remote.

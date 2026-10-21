#!/usr/bin/env bash
# Optional: voice search for the on-screen keyboard.
#
#   install-voice.sh                 Bluetooth voice remote (ATVV protocol) + faster-whisper in this machine
#   install-voice.sh --http URL      any remote whose microphone is a PipeWire/PulseAudio source (for example the 2.4 GHz
#                                    dongle of a G20S), transcription by a server that speaks the OpenAI audio API
#                                    (whisper.cpp server, faster-whisper-server): nothing else to install, no model here.
#                                    LANGS="fr,en" install-voice.sh --http http://127.0.0.1:8178
#
# No sudo needed except to pair a Bluetooth remote.
#   1. atvvoice  : exposes the remote's mic as a PipeWire source (prebuilt binary from github.com/b0o/ATVVoice)
#   2. g20-voice : listens when the keyboard's mic key is pressed (or the Bluetooth mic key is held), transcribes
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

set_conf() {   # set_conf KEY VALUE : writes or replaces a line of ~/.config/g20/g20.conf
  local f="$HOME/.config/g20/g20.conf"; mkdir -p "$(dirname "$f")"; touch "$f"
  if grep -q "^$1=" "$f"; then sed -i "s|^$1=.*|$1=$2|" "$f"; else printf '%s=%s\n' "$1" "$2" >> "$f"; fi
}

if [ "${1:-}" = "--http" ]; then
  URL=${2:?usage: install-voice.sh --http http://host:port}
  mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
  install -m 755 "$here/g20-voice" "$HOME/.local/bin/g20-voice"
  set_conf G20_VOICE_BACKEND http; set_conf G20_VOICE_URL "$URL"
  grep -q '^G20_VOICE_LANGS=' "$HOME/.config/g20/g20.conf" || set_conf G20_VOICE_LANGS "${LANGS:-en}"
  command -v parecord >/dev/null || echo "Missing: parecord (package pulseaudio-utils). The keyboard's mic key needs it."
  # A remote whose microphone is a USB audio input streams sound (LED blinking, batteries draining) for as long as PipeWire keeps
  # that input open, and some distributions (Bazzite) never let audio devices suspend. Let the remote's input close when unused.
  VENDOR=$(grep -E '^G20_DEVICE_NAME=' "$HOME/.config/g20/g20.conf" 2>/dev/null | cut -d= -f2- | tr -d '"' | awk '{print $1}')
  if [ -n "$VENDOR" ]; then
    mkdir -p "$HOME/.config/wireplumber/wireplumber.conf.d"
    cat > "$HOME/.config/wireplumber/wireplumber.conf.d/52-remote-mic-suspend.conf" <<RULE
# Lets the microphone of the remote's USB dongle close 3 seconds after its last use, so the remote stops streaming sound.
monitor.alsa.rules = [
  {
    matches = [ { node.name = "~alsa_input.usb-$VENDOR*" } ]
    actions = { update-props = { session.suspend-timeout-seconds = 3, node.pause-on-idle = true } }
  }
]
RULE
    systemctl --user restart wireplumber.service 2>/dev/null || true
  fi
  cat > "$HOME/.config/systemd/user/g20-voice.service" <<'UNIT'
[Unit]
Description=G20 voice search (microphone to text, through a transcription server)

[Service]
ExecStart=/usr/bin/python3 %h/.local/bin/g20-voice
Restart=always
RestartSec=5
Nice=5

[Install]
WantedBy=default.target
UNIT
  systemctl --user daemon-reload
  systemctl --user enable --now g20-voice.service
  echo "Voice is installed (server: $URL). Press the mic key on the on-screen keyboard and speak."
  exit 0
fi

D=$HOME/.local/share/g20-voice; mkdir -p "$D" "$HOME/.local/bin" "$HOME/.config/systemd/user"
echo "== atvvoice"
V=$(curl -fsSL https://api.github.com/repos/b0o/ATVVoice/releases/latest | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
curl -fL -o "$HOME/.local/bin/atvvoice" "https://github.com/b0o/ATVVoice/releases/download/$V/atvvoice-$(uname -m)-linux"
chmod +x "$HOME/.local/bin/atvvoice"
echo "== python environment (faster-whisper)"
python3 -m venv --system-site-packages "$D/venv"
"$D/venv/bin/pip" install --quiet --upgrade pip
PKGS="faster-whisper av==15.*"
command -v nvidia-smi >/dev/null && PKGS="$PKGS nvidia-cublas-cu12 nvidia-cudnn-cu12==9.*"
"$D/venv/bin/pip" install --quiet $PKGS
install -m 755 "$here/g20-voice" "$HOME/.local/bin/g20-voice"
cat > "$D/run.sh" <<'RUN'
#!/usr/bin/env bash
# Starts g20-voice with the CUDA libraries that pip installed next to faster-whisper.
D=$HOME/.local/share/g20-voice
LIBS=$(ls -d "$D"/venv/lib/python3*/site-packages/nvidia/*/lib 2>/dev/null | tr '\n' ':')
export LD_LIBRARY_PATH="$LIBS${LD_LIBRARY_PATH:-}"
exec "$D/venv/bin/python" "$HOME/.local/bin/g20-voice"
RUN
chmod +x "$D/run.sh"
install -m 644 "$here/atvvoice.service" "$HOME/.config/systemd/user/atvvoice.service"
install -m 644 "$here/g20-voice.service" "$HOME/.config/systemd/user/g20-voice.service"
systemctl --user daemon-reload
echo "== downloading the speech model (first run only)"
MODEL=$(grep -E '^G20_VOICE_MODEL=' "$HOME/.config/g20/g20.conf" 2>/dev/null | cut -d= -f2 || true); MODEL=${MODEL:-small}
LD_LIBRARY_PATH="$(ls -d "$D"/venv/lib/python3*/site-packages/nvidia/*/lib 2>/dev/null | tr '\n' ':')" \
  "$D/venv/bin/python" -c "from faster_whisper import WhisperModel; WhisperModel('$MODEL', device='cpu', compute_type='int8'); print('model ready')"
systemctl --user enable --now atvvoice.service g20-voice.service
cat <<MSG

Voice is installed. Pair your remote over Bluetooth (once):
  bluetoothctl            then:  scan on, pair <MAC>, trust <MAC>, connect <MAC>
(put the remote in Bluetooth pairing mode first), then run  sudo bin/g20-setup  again so the Bluetooth device gets its key mapping.
Hold the mic key and speak. Languages: G20_VOICE_LANGS in ~/.config/g20/g20.conf (e.g. fr,en).
MSG

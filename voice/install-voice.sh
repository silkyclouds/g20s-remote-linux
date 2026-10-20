#!/usr/bin/env bash
# Optional: voice search for a BLUETOOTH voice remote (ATVV protocol). No sudo needed except to pair the remote.
#   1. atvvoice  : exposes the remote's mic as a PipeWire source (prebuilt binary from github.com/b0o/ATVVoice)
#   2. g20-voice : records while the mic key is held, transcribes with faster-whisper (GPU if NVIDIA, else CPU)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
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

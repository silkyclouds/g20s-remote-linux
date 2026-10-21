"""Tests for the pure parts of voice/g20-voice: end of speech, transcription through an HTTP server, the control socket."""
import http.server
import importlib.machinery
import importlib.util
import json
import os
import socket
import struct
import subprocess
import tempfile
import threading
import unittest
import wave
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
VOICE = os.path.join(HERE, "..", "voice", "g20-voice")


def load_voice():
    loader = importlib.machinery.SourceFileLoader("g20_voice", VOICE)
    spec = importlib.util.spec_from_loader("g20_voice", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def pcm(level, seconds=0.1, rate=16000):
    """Constant-amplitude 16-bit samples, so chunk_rms returns `level`."""
    return struct.pack("<%dh" % int(rate * seconds), *([level] * int(rate * seconds)))


def wav_file(seconds, level=3000):
    path = tempfile.mktemp(suffix=".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(16000)
        w.writeframes(pcm(level, seconds))
    return path


class EndpointerTest(unittest.TestCase):
    def setUp(self):
        self.v = load_voice()

    def run_levels(self, levels, **kwargs):
        ep = self.v.Endpointer(**kwargs)
        for level in levels:
            verdict = ep.feed(level)
            if verdict:
                return verdict, ep
        return None, ep

    def test_stops_after_the_silence_that_follows_speech(self):
        quiet, speech = 40, 2000
        verdict, ep = self.run_levels([quiet] * 3 + [speech] * 8 + [quiet] * 12, silence=1.0)
        self.assertEqual(verdict, "speech")
        self.assertTrue(ep.heard)

    def test_a_short_pause_does_not_end_the_recording(self):
        quiet, speech = 40, 2000
        verdict, _ = self.run_levels([quiet] * 3 + [speech] * 5 + [quiet] * 5 + [speech] * 5 + [quiet] * 5, silence=1.0)
        self.assertIsNone(verdict)

    def test_gives_up_when_nobody_speaks(self):
        verdict, ep = self.run_levels([40] * 100, max_wait=3.0)
        self.assertEqual(verdict, "nothing")
        self.assertFalse(ep.heard)

    def test_a_steady_hum_is_not_speech(self):
        verdict, ep = self.run_levels([300] * 100, max_wait=3.0)
        self.assertEqual(verdict, "nothing")
        self.assertFalse(ep.heard)

    def test_the_total_length_is_capped(self):
        verdict, _ = self.run_levels([40] * 3 + [2000] * 400, max_total=5.0)
        self.assertEqual(verdict, "speech")

    def test_chunk_loudness(self):
        self.assertAlmostEqual(self.v.chunk_rms(pcm(1000)), 1000, delta=1)
        self.assertEqual(self.v.chunk_rms(b""), 0.0)


class _Server(http.server.BaseHTTPRequestHandler):
    calls = []
    answers = []

    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        _Server.calls.append(body.decode("latin-1"))
        answer = _Server.answers.pop(0)
        data = json.dumps(answer).encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


class HttpTranscriptionTest(unittest.TestCase):
    def setUp(self):
        _Server.calls, _Server.answers = [], []
        self.httpd = http.server.HTTPServer(("127.0.0.1", 0), _Server)
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()
        self.addCleanup(self.httpd.shutdown)
        self.url = "http://127.0.0.1:%d" % self.httpd.server_port

    def voice(self, langs):
        v = load_voice()
        v.BACKEND, v.URL, v.LANGS = "http", self.url, langs
        return v

    def test_one_language_is_sent_to_the_server(self):
        _Server.answers = [{"text": " dix pour cent "}]
        lang, text = self.voice(["fr"]).transcribe(wav_file(1.0))
        self.assertEqual((lang, text), ("fr", "dix pour cent"))
        self.assertIn('name="language"', _Server.calls[0])

    def test_several_languages_use_the_detected_one(self):
        _Server.answers = [{"text": "the grand budapest hotel", "language": "english"}]
        lang, text = self.voice(["fr", "en"]).transcribe(wav_file(1.0))
        self.assertEqual((lang, text), ("en", "the grand budapest hotel"))
        self.assertEqual(len(_Server.calls), 1)
        self.assertNotIn('name="language"', _Server.calls[0])

    def test_an_unexpected_language_is_asked_again_in_the_default(self):
        _Server.answers = [{"text": "???", "language": "german"}, {"text": "les gardiens de l'eau"}]
        lang, text = self.voice(["fr", "en"]).transcribe(wav_file(1.0))
        self.assertEqual((lang, text), ("fr", "les gardiens de l'eau"))
        self.assertEqual(len(_Server.calls), 2)
        self.assertIn('name="language"', _Server.calls[1])

    def test_a_clip_that_is_too_short_is_ignored(self):
        self.assertEqual(self.voice(["fr"]).transcribe(wav_file(0.2)), (None, ""))
        self.assertEqual(_Server.calls, [])


class CancelTest(unittest.TestCase):
    def test_a_cancelled_recording_returns_nothing(self):
        v = load_voice()
        calls = {"n": 0}

        def cancelled():
            calls["n"] += 1
            return calls["n"] > 2

        # `yes` stands in for the recorder: endless loud samples, so only the cancel can end the recording.
        real_popen = subprocess.Popen
        with mock.patch.object(v.subprocess, "Popen", lambda cmd, **kw: real_popen(["yes"], **kw)):
            self.assertIsNone(v.record_until_silence("any", cancelled))


class ControlSocketTest(unittest.TestCase):
    def test_one_session_at_a_time(self):
        v = load_voice()
        started = threading.Event()
        release = threading.Event()

        def fake_run(self_):
            started.set()
            release.wait(2)
            self_.busy.release()

        v.Listener._run = fake_run
        listener = v.Listener()
        self.assertEqual(listener.start(), "ok")
        started.wait(2)
        self.assertEqual(listener.start(), "busy")
        release.set()

    def test_start_command_over_the_socket(self):
        v = load_voice()
        v.CTL = os.path.join(tempfile.mkdtemp(), "ctl")
        calls = []

        class Fake:
            def start(self):
                calls.append(1)
                return "ok"

        threading.Thread(target=v.serve_control, args=(Fake(),), daemon=True).start()
        for _ in range(50):
            if os.path.exists(v.CTL):
                break
            threading.Event().wait(0.05)
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as c:
            c.connect(v.CTL)
            c.sendall(b"start")
            self.assertEqual(c.recv(16), b"ok")
        self.assertEqual(calls, [1])


if __name__ == "__main__":
    unittest.main()

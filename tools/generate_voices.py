"""Genererar röstfiler för NPC-dialog och barks via Piper (lokal TTS).

Användning:   python tools/generate_voices.py [--force]
Kräver:       pip install piper-tts
              ffmpeg i PATH för .ogg-konvertering (annars behålls .wav — spelet spelar båda)
Röstmodeller laddas ner automatiskt till tools/voices/ första gången.
Hash-manifest (tools/voice_manifest.json) gör att bara nya/ändrade rader genereras.
Backend-klassen är utbytbar — en ElevenLabsBackend kan pluggas in per NPC senare.
"""
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VOICE_DIR = ROOT / "audio" / "voice"
MODEL_DIR = Path(__file__).resolve().parent / "voices"
MANIFEST = Path(__file__).resolve().parent / "voice_manifest.json"

# Justera vid behov efter `python -m piper --help`:
ARG_MODEL = "--model"
ARG_OUTPUT = "--output-file"
ARG_LENGTH = "--length-scale"
ARG_DATA_DIR = "--data-dir"


class PiperBackend:
    def synth(self, text: str, voice: dict, wav_path: Path) -> None:
        self._ensure_model(voice["model"])
        cmd = [sys.executable, "-m", "piper",
               ARG_MODEL, voice["model"],
               ARG_DATA_DIR, str(MODEL_DIR),
               ARG_LENGTH, str(float(voice.get("length_scale", 1.0))),
               ARG_OUTPUT, str(wav_path)]
        subprocess.run(cmd, input=text.encode("utf-8"), check=True)

    def _ensure_model(self, model: str) -> None:
        # piper-tts >= 1.3 laddar inte ner röster själv — hämta vid behov
        if not (MODEL_DIR / f"{model}.onnx").exists():
            subprocess.run([sys.executable, "-m", "piper.download_voices",
                            model, ARG_DATA_DIR, str(MODEL_DIR)], check=True)


def to_ogg(wav_path: Path) -> Path:
    if shutil.which("ffmpeg") is None:
        return wav_path  # behåll .wav
    ogg = wav_path.with_suffix(".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error",
                    "-i", str(wav_path), str(ogg)], check=True)
    wav_path.unlink()
    return ogg


def line_hash(text: str, voice: dict) -> str:
    return hashlib.sha1(json.dumps([text, voice], sort_keys=True).encode()).hexdigest()


def main() -> None:
    force = "--force" in sys.argv
    npcs = json.loads((ROOT / "data" / "npcs.json").read_text(encoding="utf-8"))
    nodes = json.loads((ROOT / "data" / "dialogue.json").read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    backend = PiperBackend()

    jobs = []  # (npc_id, line_id, text)
    for node_id, n in nodes.items():
        jobs.append((n["speaker"], node_id, n["text"]))
    for npc_id, npc in npcs.items():
        for i, bark in enumerate(npc.get("barks", [])):
            jobs.append((npc_id, f"bark_{i}", bark))

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    done = skipped = 0
    for npc_id, line_id, text in jobs:
        voice = npcs[npc_id]["voice"]
        key = f"{npc_id}/{line_id}"
        h = line_hash(text, voice)
        out_dir = VOICE_DIR / npc_id
        exists = any((out_dir / f"{line_id}{ext}").exists() for ext in (".ogg", ".wav"))
        if not force and manifest.get(key) == h and exists:
            skipped += 1
            continue
        out_dir.mkdir(parents=True, exist_ok=True)
        wav = out_dir / f"{line_id}.wav"
        backend.synth(text, voice, wav)
        to_ogg(wav)
        manifest[key] = h
        done += 1
        print(f"  {key}")

    MANIFEST.write_text(json.dumps(manifest, indent=1, sort_keys=True), encoding="utf-8")
    print(f"Genererade {done}, hoppade över {skipped}.")


if __name__ == "__main__":
    main()

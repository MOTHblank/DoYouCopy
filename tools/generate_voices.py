#!/usr/bin/env python3
"""Offline authored voice export for Do You Copy?.

Usage:
    python tools/generate_voices.py --backend espeak
    python tools/generate_voices.py --backend piper --actual-model model-a.onnx --echo2-model model-b.onnx

Requires ffmpeg; espeak/espeak-ng for the espeak backend or Piper with two
locally available models for the piper backend. Nothing runs at game runtime.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
CONTACTS = ROOT / "content" / "contacts"
DEST = ROOT / "content" / "voices" / "generated"

def get_value(source: str, key: str) -> str:
    pattern = rf"^{re.escape(key)}\s*=\s*(\"(?:\\.|[^\"])*\")\s*$"
    found = re.search(pattern, source, re.MULTILINE)
    return json.loads(found.group(1)) if found else ""

def lines_for_contact(path: Path):
    source = path.read_text(encoding="utf-8")
    id_match = re.search(r'^id\s*=\s*&"([^"]+)"', source, re.MULTILINE)
    if not id_match:
        raise ValueError(f"Missing contact ID: {path}")
    contact_id = id_match.group(1)
    claim_match = re.search(r'^claimed_callsign\s*=\s*&"([^"]+)"', source, re.MULTILINE)
    if not claim_match:
        raise ValueError(f"Missing claimed voice: {path}")
    speaker = claim_match.group(1)
    clips = []
    for attr, suffix in [
        ("opening_line", "OPEN"),
        ("repeat_line", "REPEAT"),
        ("authentication_line", "AUTH"),
        ("fallback_authentication_line", "AUTH_FALLBACK"),
        ("fallback_opening", "OPEN_FALLBACK"),
        ("parallel_line", "PARALLEL"),
    ]:
        text = get_value(source, attr)
        if text:
            clips.append((f"{contact_id}_{suffix}", speaker, text))
    branch_block = re.search(r"^branch_openings\s*=\s*\{(.*?)^\}", source, re.MULTILINE | re.DOTALL)
    if branch_block:
        for entry in re.finditer(r'^"([^"]+)"\s*:\s*(\"(?:\\.|[^\"])*\")', branch_block.group(1), re.MULTILINE):
            flag, raw = entry.groups()
            clips.append((f"{contact_id}_OPEN_{flag}", speaker, json.loads(raw)))
    return clips

def render_wav(backend: str, speaker: str, text: str, out: Path, args):
    if backend == "espeak":
        app = shutil.which("espeak-ng") or shutil.which("espeak")
        if not app:
            raise RuntimeError("Install espeak-ng or espeak first.")
        voice = "en-us+m3" if speaker == "ECHO-ACTUAL" else "en-us+f3"
        subprocess.run([app, "-v", voice, "-s", "135" if speaker == "ECHO-ACTUAL" else "159", "-w", str(out), text], check=True)
    else:
        model = args.actual_model if speaker == "ECHO-ACTUAL" else args.echo2_model
        if not model:
            raise RuntimeError("Provide both --actual-model and --echo2-model for Piper.")
        app = shutil.which("piper")
        if not app:
            raise RuntimeError("Install Piper first.")
        subprocess.run([app, "--model", model, "--output_file", str(out)], input=text.encode("utf-8"), check=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", choices=("espeak", "piper"), default="espeak")
    parser.add_argument("--actual-model")
    parser.add_argument("--echo2-model")
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()
    if not shutil.which("ffmpeg"):
        parser.error("ffmpeg is required to encode game clips.")
    DEST.mkdir(parents=True, exist_ok=True)
    clips = []
    for path in sorted(CONTACTS.glob("contact_*.tres")):
        clips.extend(lines_for_contact(path))
    if not clips:
        parser.error("No authored lines found.")
    created = 0
    with tempfile.TemporaryDirectory() as folder:
        for line_id, speaker, text in clips:
            target = DEST / (line_id + ".ogg")
            if target.exists() and not args.overwrite:
                continue
            wav = Path(folder) / (line_id + ".wav")
            render_wav(args.backend, speaker, text, wav, args)
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-i", str(wav), "-ar", "24000", "-ac", "1",
                "-c:a", "libvorbis", "-qscale:a", "4", str(target)
            ], check=True)
            created += 1
    print(f"Generated {created} clips ({len(clips)} authored line variants).")
    print("Clips are local until you explicitly commit them. Never auto-regenerate in the game.")

if __name__ == "__main__":
    main()

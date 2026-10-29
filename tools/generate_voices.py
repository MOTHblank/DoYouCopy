#!/usr/bin/env python3
"""Offline authored radio-voice renderer. Never runs in the game process.

Generate preview voices:
    python tools/generate_voices.py --backend espeak --overwrite
Use Piper models for final actors:
    python tools/generate_voices.py --backend piper --actual-model actual.onnx --echo2-model two.onnx --overwrite
Inspect the list without rendering:
    python tools/generate_voices.py --dry-run

The claimed identity selects the same voice for a real agent and its copy.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
CONTACTS = ROOT / "content" / "contacts"
DEST = ROOT / "content" / "voices" / "generated"

VALUE = r'"(?:\\.|[^"\\])*"'

def find_string(source: str, key: str) -> str:
    match = re.search(rf"^{re.escape(key)}\s*=\s*({VALUE})\s*$", source, re.M)
    return json.loads(match.group(1)) if match else ""

def find_name(source: str, key: str) -> str:
    match = re.search(rf'^{re.escape(key)}\s*=\s*&"([^"]+)"', source, re.M)
    if not match:
        raise ValueError(f"Missing {key}")
    return match.group(1)

def lines_for_contact(path: Path):
    source = path.read_text(encoding="utf-8")
    contact_id = find_name(source, "id")
    speaker = find_name(source, "claimed_callsign")
    if speaker not in ("ECHO-ACTUAL", "ECHO-2"):
        raise ValueError(f"{contact_id}: unsupported agent voice {speaker}")
    clips = []
    for attribute, suffix in (
        ("opening_line", "OPEN"),
        ("repeat_line", "REPEAT"),
        ("authentication_line", "AUTH"),
        ("fallback_authentication_line", "AUTH_FALLBACK"),
        ("fallback_opening", "OPEN_FALLBACK"),
        ("parallel_line", "PARALLEL"),
    ):
        message = find_string(source, attribute)
        if message.strip():
            clips.append((f"{contact_id}_{suffix}", speaker, message.strip()))
    branches = re.search(r"^branch_openings\s*=\s*\{(.*?)^\}", source, re.M | re.S)
    if branches:
        for match in re.finditer(rf'^"([^"]+)"\s*:\s*({VALUE})', branches.group(1), re.M):
            flag, quoted = match.groups()
            message = json.loads(quoted).strip()
            if message:
                clips.append((f"{contact_id}_OPEN_{flag}", speaker, message))
    return clips

def clip_manifest(clips, backend, models):
    records = {}
    for clip_id, speaker, message in clips:
        if clip_id in records:
            raise ValueError(f"Duplicate stable line ID {clip_id}")
        profile = models.get(speaker, "espeak-default")
        checksum = hashlib.sha256(
            f"{speaker}\n{message}\n{backend}\n{profile}".encode("utf-8")
        ).hexdigest()
        records[clip_id] = {
            "speaker": speaker, "text": message, "profile": profile,
            "source_hash": checksum,
        }
    return {"schema": 1, "backend": backend, "clips": records}

def render_wav(backend, speaker, message, target, models):
    if backend == "espeak":
        tool = shutil.which("espeak-ng") or shutil.which("espeak")
        if not tool:
            raise RuntimeError("Install espeak-ng or espeak to render preview audio.")
        voice = "en-us+m3" if speaker == "ECHO-ACTUAL" else "en-us+f3"
        speed = "140" if speaker == "ECHO-ACTUAL" else "162"
        subprocess.run([tool, "-v", voice, "-s", speed, "-w", str(target), message], check=True)
        return
    tool = shutil.which("piper")
    if not tool:
        raise RuntimeError("Install Piper before choosing --backend piper.")
    model = models.get(speaker)
    if not model:
        raise RuntimeError(f"Missing Piper model for {speaker}")
    subprocess.run([tool, "--model", model, "--output_file", str(target)],
                   input=message.encode("utf-8"), check=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", choices=("espeak", "piper"), default="espeak")
    parser.add_argument("--actual-model", default="")
    parser.add_argument("--echo2-model", default="")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    clips = []
    for path in sorted(CONTACTS.glob("contact_*.tres")):
        clips.extend(lines_for_contact(path))
    if not clips:
        parser.error("No authored radio dialogue was found.")
    models = {"ECHO-ACTUAL": args.actual_model, "ECHO-2": args.echo2_model}
    if args.backend == "piper" and not all(models.values()):
        parser.error("Piper requires --actual-model and --echo2-model.")
    manifest = clip_manifest(clips, args.backend, models)
    print(f"{len(clips)} voice lines for 2 identities; {len(list(CONTACTS.glob('contact_*.tres')))} contacts.")
    if args.dry_run:
        for clip_id, speaker, _ in clips:
            print(f"{clip_id}: {speaker}")
        return
    if not shutil.which("ffmpeg"):
        parser.error("Install ffmpeg to encode .ogg audio.")
    DEST.mkdir(parents=True, exist_ok=True)
    created = 0
    with tempfile.TemporaryDirectory() as work:
        for clip_id, speaker, message in clips:
            destination = DEST / f"{clip_id}.ogg"
            if destination.exists() and not args.overwrite:
                continue
            wave = Path(work) / f"{clip_id}.wav"
            render_wav(args.backend, speaker, message, wave, models)
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-i", str(wave), "-ar", "24000", "-ac", "1",
                "-c:a", "libvorbis", "-qscale:a", "3", str(destination)
            ], check=True)
            created += 1
    (DEST / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"Rendered {created} audio clips and updated manifest.json.")

if __name__ == "__main__":
    main()

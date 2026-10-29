#!/usr/bin/env python3
"""Fast stdlib-only authored-content check; does not replace launching Godot."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
CONTACT_DIR = ROOT / "content" / "contacts"
ALLOWED_ACTIONS = {"HOLD", "PROCEED", "REROUTE"}
errors = []
warnings = []

def value(source: str, name: str):
    match = re.search(rf'^{re.escape(name)}\s*=\s*&?"([^"]*)"', source, re.M)
    return match.group(1) if match else None

def packed(source: str, name: str):
    match = re.search(rf"^{re.escape(name)}\s*=\s*PackedStringArray\(([^)]*)\)", source, re.M)
    return re.findall(r'"([^"]+)"', match.group(1)) if match else []

def check_reference_paths():
    script_files = list((ROOT / "game").rglob("*.gd"))
    scene_files = list((ROOT / "game").rglob("*.tscn"))
    scene_files += list((ROOT / "content").rglob("*.tres"))
    scene_files += list((ROOT / "tests").rglob("*.gd"))
    for path in script_files + scene_files:
        source = path.read_text(encoding="utf-8")
        # Dynamic format-string lookups may point to intentionally unbuilt
        # voice clips; keep those separate from static preloads.
        for raw in re.findall(r'(?:preload\(|path=)"res://([^"]+)"', source):
            if not (ROOT / raw).is_file():
                errors.append(f"{path.relative_to(ROOT)}: missing res://{raw}")
    return len(script_files) + len(scene_files)

def check_contacts():
    seen = set()
    heard_facts = set()
    contacts = sorted(CONTACT_DIR.glob("contact_*.tres"))
    if len(contacts) != 8:
        errors.append(f"Expected 8 major contacts; found {len(contacts)}")
    for path in contacts:
        source = path.read_text(encoding="utf-8")
        identifier = value(source, "id")
        callsign = value(source, "claimed_callsign")
        channel = value(source, "channel")
        challenge = value(source, "challenge_id")
        if not identifier or identifier in seen:
            errors.append(f"{path.name}: missing or duplicated ID {identifier!r}")
        seen.add(identifier)
        if callsign not in {"ECHO-ACTUAL", "ECHO-2"}:
            errors.append(f"{path.name}: unknown callsign")
        if channel not in {"A-PRIMARY", "B-PRIMARY", "A-ALT", "B-ALT"}:
            errors.append(f"{path.name}: unsupported channel {channel!r}")
        if not challenge:
            errors.append(f"{path.name}: no authentication reference")
        actions = packed(source, "possible_actions")
        if not actions or not set(actions) <= ALLOWED_ACTIONS:
            errors.append(f"{path.name}: invalid response options")
        for name in ("auth_requires_knowledge", "opening_requires_knowledge"):
            fact = value(source, name)
            if fact and fact not in heard_facts:
                warnings.append(f"{path.name}: {name} can only use fallback unless {fact} was learned")
        for fact in packed(source, "required_ghost_knowledge"):
            if fact not in heard_facts:
                errors.append(f"{path.name}: impossible GHOST prerequisite {fact}")
        for name in ("learned_on_receive", "learned_on_authentication"):
            heard_facts.update(packed(source, name))
    return len(contacts)

def main():
    checked = check_reference_paths()
    count = check_contacts()
    for issue in warnings:
        print("WARNING:", issue)
    for issue in errors:
        print("ERROR:", issue, file=sys.stderr)
    print(f"Checked {count} authored contacts and {checked} Godot source/scene files.")
    if errors:
        sys.exit(1)
    print("PASS: static references, contact IDs, response choices and potential GHOST provenance.")

if __name__ == "__main__":
    main()

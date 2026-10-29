# Voice production and radio audio

The game uses **pre-generated, authored OGG clips**, not runtime TTS. Every
contact resource provides text and a stable line ID. The same agent profile
is used for legitimate ECHO-ACTUAL/ECHO-2 voices and their GHOST copies.
An unrecognized/absent audio clip falls back to the onscreen transcript;
this never blocks the contact.

## Preview files produced automatically on main

The [Render authored radio voices](../.github/workflows/render-voices.yml)
workflow uses espeak-ng and ffmpeg on GitHub's Linux runner, producing
`content/voices/generated/<line_id>.ogg` and a matching `manifest.json`.
It commits generated previews to **main**, not a secondary branch.
Workflow changes to the authored contacts or voice tool cause regeneration.

The files are **functional synthetic placeholders** for development. They are
intended to establish distinctive, consistent radio identities, not final
acting. Do not mistake robotic preview speech for the final dramatic reading.

## Render locally

Requires Python 3, ffmpeg, and espeak-ng (or espeak):

```shell
python tools/generate_voices.py --dry-run
python tools/generate_voices.py --backend espeak --overwrite
```

To replace placeholder voices with higher-quality offline Piper recordings,
install Piper and provide two locally available models:

```shell
python tools/generate_voices.py --backend piper --actual-model actual.onnx --echo2-model two.onnx --overwrite
```

You should review every generated line before shipping, particularly
authentication keywords (KEYBOARD, RIVER, SHADOW, BRIDGE). Commit your
reviewed OGGs together with the manifest. The automatic preview renderer is
still enabled and may overwrite them if the workflow is triggered; disable
or change its trigger after final art is approved.

## Playback and pacing

`AudioMixer` routes distinct voice, static and interface buses to Master.
The voice bus uses a 300–3200 Hz band limit and mild compression. Both
real and copied identities share this chain. `RadioStatic` automatically
ducks while an authored line plays to preserve comprehension.

The current contact stays in **RECEIVING** until any queued opening speech
finishes. Afterward it enters **VERIFYING** so players cannot commit a
decision before hearing the evidence. If no clip exists, transcript-only
play proceeds immediately. R / REPEAT remains available after acquisition.

## Verification

Use the local text-source validation script and headless Godot harness:

```shell
python tools/validate_content.py
godot --headless --path . --script res://tests/scenario/run_campaign.gd
```

The full target remains a 25–35-minute game; adding automatically generated
voice clips does not itself prove the pacing target or audio quality.

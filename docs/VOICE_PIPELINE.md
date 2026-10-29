# Authored radio voices

Godot's `RadioVoice` looks for a clip matching each stable dialogue ID, for
example `content/voices/generated/C05_PARALLEL.ogg`. The terminal always shows
the matching transcript, even if a clip has not been generated yet. Voice
playback is an **optional asset layer**, not runtime AI/TTS.

Generate locally from the contact resources:

```shell
python tools/generate_voices.py --backend espeak
```

Requires `ffmpeg` and `espeak-ng` or `espeak`. For higher-quality offline
Piper models, supply **two distinct local model paths**:

```shell
python tools/generate_voices.py --backend piper --actual-model actual.onnx --echo2-model two.onnx
```

Generated `.ogg` clips are intended to be committed before shipping. GHOST
lines use the **same voice profile as their claimed agent**. C05's secondary
carrier also uses ECHO-ACTUAL's profile. Do not use monster effects or a third
voice. Listen to each export and replace any unclear lines before release.

The current repository ships the loader/generator, **not** pre-rendered voice
recordings. Audio buses, filtering, compression, light saturation, and a
hand-animated operator arm remain polish tasks.

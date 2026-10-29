# Do You Copy? — complete authored scenario foundation

The GitHub main branch contains a Godot 4.7 project with eight authored major radio contacts, the three ending families, and a low-poly single-room workstation. **This is a gameplay implementation, not yet a runtime-verified or fully voiced release.** Open `project.godot` in Godot 4.7 and run the main scene (F5).

## Operator controls

- **Right-mouse drag**: constrained seated camera look.
- **Left-click**: inspect paper/terminal/map, select a response, operate the microphone, or press the physical REPEAT / AUTH buttons.
- **Drag the physical radio knobs**: adjust frequency or cleanup. The last selected knob also receives the mouse wheel.
- **Mouse wheel / Up / Down**: frequency tuning (0.05 MHz steps when focused on the frequency knob).
- **Frequency box + cleanup slider**: acquire and clean the incoming carrier. Normal acquisition is intentionally short.
- **R / A**: REPEAT / AUTHENTICATE.
- **1 / 2 / 3**: select HOLD / PROCEED / REROUTE. Selection is **not** transmission.
- **Space / Enter / microphone**: send the selected instruction. The operator arm reaches for the microphone. The lower-left controls provide the same interaction without pixel-perfect 3D targeting.
- **Q**: request quarantine after the safety guard unlocks. A **confirmation dialog** shows the channel and whether a real agent relies on it. Up to two channels can be sealed; this cannot be undone.
- **Enter**: advance after a consequence; restart from the ending report.
- **Reference desk**: terminal, staged authentication sheets, verified map, and a communication log remain independently inspectable. The wall map is also drawn in code with verified agent positions.

## Eight-contact campaign (design spoilers)

1. **C01 / 101.30 / ECHO-ACTUAL** — training, DELTA-4, first verified instruction.
2. **C02 / 104.70 / ECHO-2** — normal speech behavior, TIDE-2, field positions.
3. **C03 / 104.15 / GHOST as ECHO-2** — unassigned carrier and incorrect/obsolete authentication. Retired TIDE-2 is spoken only if the GHOST overheard it.
4. **C04 / 101.30 / ECHO-ACTUAL** — previous decision's consequence and BRAVO-6 challenge.
5. **C05 / 101.30 + 101.85 intercept** — two claims using Actual's voice; one contradicts the verified blue-door order. Authorship of the second intercept requires previously learned voice/callsign.
6. **C06 / 101.85 / GHOST as Actual** — DELTA-4, an obsolete answer, is produced only when previously overheard. Quarantine becomes available **after** this contact resolves.
7. **C07 / 101.85 / learned copy** — can answer the current BRAVO-6 only if overheard from an earlier real contact. Quarantine here can permanently seal A-ALT, without cutting Actual's primary route.
8. **C08 / 101.30 / ECHO-ACTUAL** — terminal synchronization conflicts with the last independently verified map. The final decision determines containment alongside earlier mistakes and whether a real channel was sacrificed.

If C07's A-ALT channel was sealed, C08 still takes place on A-PRIMARY. A second quarantine can cut Actual's **legitimate primary route**, leading to an isolation cost.

## State and ownership

- `ContactDefinition`: stable IDs, authored voice lines, secondary carriers, rule-gated phrases, conditional openings, operational outcomes, and anomaly flags.
- `ScenarioDirector`: interaction lifecycle and contact eligibility. Acquiring a signal, repeating a line, challenging identity, deciding and quarantining are explicit events.
- `ScenarioState`: verified field positions, asymmetric agent statuses/trust, permanent channel seals, bounded GHOST knowledge with provenance, flags, operator choices, and ending resolution.
- `RadioConsole`: frequency and signal cleanup only. It does not know whether a caller is authentic.
- `WorkstationHUD`: readable diegetic reference and controls. The terminal can present a false *synchronized* location; the reference map continues to show the real verified location.
- `WorkstationRoom`: procedural office, projected spectrum/terminal/map displays, physical radio knobs, response keys, protected quarantine control, and subtly changing workstation lighting.
- `PlayerRig` / `OperatorArm`: ray selection, knob dragging, and a simple procedural arm animation. This is a temporary stand-in for the intended Blender rig, not a finished rigged character animation.
- `RadioStatic`: small precomputed looping noise sample; dynamically quieter as reception improves. It avoids expensive per-frame audio generation and keeps critical radio words intelligible.
- `RadioVoice`: optional playback of authored offline OGG clips keyed by stable IDs, **never runtime TTS**; text log always remains available.

## Current limitations

Runtime validation in Godot remains necessary. The repository has a headless scenario verification script but it has not been run in the current authoring environment. Actual OGG voice recordings have **not** yet been committed; see [voice generation](docs/VOICE_PIPELINE.md). State Charts and Dialogue Manager integration, the final Blender-rigged arm, voice DSP buses and a complete 25–35-minute audio/pacing pass remain future integration/polish. The current radio static and procedural arm are early presentation substitutes, not shipped-quality replacements. The contact content supplies the eight major beats, not a final timed release.

Run the headless scenario harness after importing the project:

```shell
godot --headless --path . --script res://tests/scenario/run_campaign.gd
```

## Local smoke checks

The source-level validator reports missing `res://` files, duplicate contact IDs and invalid action references without requiring Godot:

```shell
python tools/validate_content.py
```

The existing headless Godot scenario harness exercises the scenario flow and endings, but must still be run in a Godot installation. This repository was edited remotely without a Godot executable in the authoring environment, so an actual runtime/editor check has **not** been performed.

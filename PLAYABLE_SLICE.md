# Do You Copy? — complete authored scenario foundation

The GitHub main branch contains a Godot 4.7 project with eight authored major radio contacts, the three ending families, and a low-poly single-room workstation. **This is a gameplay implementation, not yet a runtime-verified or fully voiced release.** Open `project.godot` in Godot 4.7 and run the main scene (F5).

## Operator controls

- **Right-mouse drag**: constrained seated camera look.
- **Left-click**: inspect paper/terminal/map, select a response, operate the microphone, or press the physical REPEAT / AUTH buttons.
- **Drag the physical radio knobs**: adjust frequency or cleanup. The last selected knob also receives the mouse wheel.
- **Mouse wheel / Up / Down**: frequency tuning (0.05 MHz steps when focused on the frequency knob).
- **Frequency, cleanup, squelch and bandwidth**: tune the carrier, process speech, suppress static and trade filter width against voice detail. The four physical radio knobs also support drag and wheel input; default settings remain forgiving.
- **R / A**: REPEAT / AUTHENTICATE.
- **1 / 2 / 3**: select HOLD / PROCEED / REROUTE. Selection is **not** transmission.
- **Space / Enter / microphone**: send the selected instruction once the incoming message is complete. During RECEIVING, **Space / Enter** skips the preview recording; its full text remains in the communication log. The operator arm reaches for the microphone. The lower-left controls provide the same interaction without pixel-perfect 3D targeting.
- **Q**: request quarantine after the safety guard unlocks. A **confirmation dialog** shows the channel and whether a real agent relies on it. Up to two channels can be sealed; this cannot be undone.
- **Enter**: advance after a consequence; restart from the ending report.
- **Reference desk**: terminal, staged authentication sheets, verified map, communication log, and chronological reconstruction remain inspectable independently. The wall map is drawn with recorded field positions and distinct unverified operator marks.
- **RECONSTRUCTION tab**: view received transmissions, the contact brief's last-reported location, the independent field-map position as recorded at that moment, timed station events, and the decisions/consequences that followed. Use the filter above the record; it never labels a caller as true or false.
- **FIELD MAP tab**: choose a station and a hypothesis type (suspected position, possible origin, or escape route), write a short note, and add or remove it. Amber hollow marks on the physical map represent these hypotheses; they cannot change an agent's position.
- **TERMINAL tab**: displays full mission objectives and previous received transmissions. Use the MONITOR PAGE buttons (or Page Up/Page Down while this tab is selected) to scroll the in-room terminal display.

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
- `ScenarioState`: verified field positions, asymmetric agent statuses/trust, permanent channel seals, bounded GHOST knowledge with provenance, flags, operator choices, and ending resolution. Its player-facing evidence chronology stores elapsed shift timestamps, channel/callsign claims, the independent field record at reception, actions, and outcomes. Player map notes are stored separately from the authoritative positions; both are restored from completed-contact checkpoints. Earlier v1 checkpoints without these optional fields remain readable.
- `RadioConsole`: frequency and signal cleanup only. It does not know whether a caller is authentic.
- `WorkstationHUD`: readable diegetic reference and controls. The terminal can present a false *synchronized* location; the reference map continues to show the real verified location.
- `WorkstationRoom`: procedural office, projected spectrum/terminal/map displays, physical radio knobs, response keys, protected quarantine control, and subtly changing workstation lighting.
- `PlayerRig` / `OperatorArm`: ray selection, knob dragging, and a simple procedural arm animation. This is a temporary stand-in for the intended Blender rig, not a finished rigged character animation.
- `RadioStatic`: small precomputed looping noise sample; dynamically quieter as reception improves. It avoids expensive per-frame audio generation and keeps critical radio words intelligible.
- `RadioVoice`: queued playback of authored offline OGG clips keyed by stable IDs, **never runtime TTS**; text log always remains available. In normal game mode, the opening narration completes before operational choices unlock.
- `AudioMixer`: separate Voice, Static and Interface buses; band-limited voice with conservative compression. Static is ducked during transmissions.

## Current limitations

Runtime validation in Godot remains necessary. The repository has a headless scenario verification script but it has not been run in the current authoring environment. An automatic offline-rendering workflow now builds **preview** voice clips from the authored contact resources; see [voice generation](docs/VOICE_PIPELINE.md). Check the GitHub Actions run and the generated-voices directory for successful delivery. Final acting and listening review are still outstanding. State Charts and Dialogue Manager integration, the final Blender-rigged arm, voice DSP buses and a complete 25–35-minute audio/pacing pass remain future integration/polish. The current radio static and procedural arm are early presentation substitutes, not shipped-quality replacements. The contact content supplies the eight major beats, not a final timed release.

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

## Authentication paperwork authoring

The `AUTH PAPER` tab reads `content/authentication/paperwork.tres` rather than contact-specific HUD conditions. The manifest lists `AuthenticationDocument` resources in newest-first order. To add a protocol revision, create a new document in `content/authentication/` and register it in the manifest.

Each document contains the challenge ID, question, answer, revision date, current validity window, optional FILED window, visible contact window, and optional required/excluded scenario flags. Windows use **one-based contact numbers**, including contacts that could be skipped; they are not counts of successful transmissions. After its current window, a visible document becomes FILED (if configured), then RETIRED. Obsolete entries retain the answer but omit the current challenge prompt, matching the existing paperwork presentation.

The original sequence is preserved: C01 shows DELTA-4 current; C02 shows TIDE-2 current and DELTA-4 filed; C03–C07 show BRAVO-6 current with TIDE-2 and DELTA-4 retired; C08 shows NORTH-8 current with BRAVO-6 and TIDE-2 retired. DELTA-4 is no longer visible at C08.

These are **operator-facing references only**. `ScenarioDirector` continues to resolve authentication responses, and `ScenarioState.ghost_knowledge` independently governs which challenge answers the GHOST can reproduce. Showing a sheet does not teach the GHOST a fact. When adding a new challenge, also author the associated `ContactDefinition` challenge and knowledge rules explicitly.

## Per-contact reception profiles

Each `ContactDefinition` provides a `bandwidth_target` and an `interference_level`. Frequency locates the carrier, cleanup adjusts waveform processing, bandwidth changes capture width and the tradeoff between noise and voice detail, and squelch suppresses noise but can mute weak signals. The HUD sliders and radio knobs share one `RadioConsole` model. All eight contact resources have authored profiles; none of these controls determine identity or grant knowledge to the GHOST.


## Investigative receiver acquisition and intelligibility

The **first training contact** still states its exact 101.30 MHz allocation. Later
carriers are announced only within a half-MHz allocation; the physical frequency
control and live spectrum peak determine the correct tuning. A pre-tuned dial can
still acquire its next carrier immediately.

The normal comms log and received-transmission panel now record what the
receiver could actually recover at the time of reception. Partial reception
obscures consistent word groups, while adjusting cleanup, filter width and tuning
can reveal additional fragments of a received line without changing what the
caller really said. REPEAT remains available after voice playback completes;
it retransmits the authored repeat line at the current reception quality.
Weak reception also causes deterministic, short audio dropouts rather than just
volume attenuation. GHOST knowledge and authored branches are unaffected by
the quality of the operator's receiver.

For accessibility, enable **FULL VOICE SUBTITLES / ACCESSIBILITY** on the
reference desk. It reveals the full authored text of received voice lines
independently of reception quality; the normal mode remains investigative.

# Do You Copy? — playable Godot vertical slice

Open `project.godot` in **Godot 4.7**, import the project, and press **F6** on `game/main/main.tscn` or **F5** to run. The repository now contains a generated, single-room workstation with a working four-contact slice. There are no external model/texture dependencies.

## Controls

- **Mouse:** click operator controls in the readable UI or the physical workstation (paper, radio, terminal, microphone); **right-drag** to turn the seated camera.
- **Frequency:** enter the assigned MHz directly, use the numeric spinner, or use **Up/Down** (0.05 MHz steps). All contacts are between 100–110 MHz.
- **Signal cleanup:** drag the cleanup slider until the receiver reports **VOICE LOCK**. The target is deliberately forgiving; tuning is not the identity puzzle.
- **R / A:** REPEAT and AUTHENTICATE once a transmission is received.
- **1 / 2 / 3:** HOLD, PROCEED, REROUTE when the current contact permits it. You can also click the buttons.
- **Enter / Continue:** advance after the consequence has been read. Restart from the shift report.

## Contact sequence

1. **C01 / 101.30 / ECHO-ACTUAL:** routine identification, DELTA-4, first operational decision.
2. **C02 / 104.70 / ECHO-2:** speech habits, TIDE-2, choice of east route or a hold.
3. **C03 / 104.15 / claimed ECHO-2:** the false carrier is on an unassigned frequency; its retired authentication answer is available **only if the operator requested and heard TIDE-2 authentication** on the previous live contact. Compare the authentication paper and verified map. Wrong decisions alter the field state rather than ending the run.
4. **C04 / 101.30 / ECHO-ACTUAL:** explicitly branches on C03's decision and reports its consequence.

The terminal contains *claims* and last known verified positions, not a secret TRUE/FALSE judgment. The paper is an independent reference. The map is intentionally a small evidence aid, not a strategy mode.

## Architecture

- `ContactDefinition` is an authored `.tres` resource holding signal, identity claims, dialogue text, eligibility, knowledge dependencies, and per-action consequences.
- `ScenarioState` contains run-local locations, statuses, flags, decisions, channel state, and an explicit **GHOST knowledge ledger**. New facts carry provenance in `knowledge_history`.
- `ScenarioDirector` owns WAITING → TUNING → RECEIVING → VERIFYING → DECIDING → RESOLVING → COMPLETE, validates actions, and advances the scenario. Presenters do not mutate progression.
- `RadioConsole` owns tuning, cleanup, quality and acquisition; it cannot identify the caller.
- `WorkstationRoom` creates the low-poly room and maps lightweight spectrum/terminal Controls into 3D monitor SubViewports. `PlayerRig` only owns looking and workstation selection. `WorkstationHUD` is the legible fallback for interaction.
- `StationAudio` provides generated operator-interface beeps. **No radio voice assets are claimed to exist.**

## Scope of this first slice

**Implemented:** the Godot project, station blockout and lighting, fixed-position first-person camera, ray-selected props, numerical radio tuning, cleanup, live spectrum, terminal, paper/map evidence, repeat/authenticate, operational responses, four authored contacts, consequence branching, deterministic GHOST knowledge, run restart and a brief summary.

**Still to create for the full game:** recorded/TTS voice files with consistent agent voice identities, full Dialogue Manager / State Charts integration, a rigged arm, authored contacts 05–08 and the three ending families. The quarantine control is deliberately **locked** until a later contact explicitly unlocks it; no misleading irreversible action is offered in the introductory slice. The 25–35 minute pacing target is for the complete scenario, not this four-contact prototype.

This project was authored without an available Godot executable for runtime validation. The scene should be opened in Godot before calling it a verified build.

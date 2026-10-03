# Do You Copy?

> A short radio-operator horror game about deciding whether the voice on the other end is really who it claims to be.

**Do You Copy?** is a PC-first 3D horror game being built for the **v3Expo Game Jam 2**. The jam theme is **The Ghost in the Machine**.

The player is a trainee radio operator working alone in an ordinary communications office. Field agents depend on the operator to find their transmissions, verify their identities, and relay instructions. As the shift continues, something begins using the radio network.

It can imitate voices.

It can learn protocol.

Eventually, hearing the right voice is no longer enough.

## Jam constraints

The game is designed around the jam's required elements rather than treating them as separate side mechanics:

- **Theme — The Ghost in the Machine:** an unknown presence inhabits the communications network and begins impersonating field agents.
- **Modifier — Settings Not Fit for Horror:** the game takes place in a mundane, functional training/dispatch office rather than an obviously threatening environment.
- **Modifier — Sacrifice Mechanics:** the operator can permanently burn compromised radio channels. Doing so may contain the intrusion, but can also cut off a real agent who still needs help.
- **Modifier — Riddles:** challenge-response authentication uses short riddles, coded prompts, and contextual questions whose answers must be checked against paperwork and previous transmissions.

The jam runs for one week, so the project is deliberately compact.

## Core idea

The horror comes from verification.

A caller gives the correct callsign.

They are transmitting on the expected frequency.

Their voice sounds right.

But their authentication answer is from yesterday's sheet.

Do you trust them?

The player is not fighting a monster directly. They are deciding which information is real while people in the field act on those decisions.

## Core loop

1. **Find the signal**  
   Tune the receiver until a transmission becomes intelligible.

2. **Clean the signal**  
   Adjust a small set of radio controls such as gain, squelch, bandwidth, or fine tuning.

3. **Listen**  
   Receive a field report through radio-processed voice audio.

4. **Verify the caller**  
   Compare the transmission against:
   - callsign
   - assigned frequency
   - current location
   - authentication sheet
   - previous reports
   - known behavioral details

5. **Challenge them**  
   Request an authentication prompt or riddle when something does not add up.

6. **Decide**  
   Accept the transmission, reject it, relay an instruction, or permanently burn the channel.

7. **Live with the result**  
   The field situation changes. A real agent may survive, disappear, become unreachable, or be replaced by something that sounds exactly like them.

## Identity verification

Identity checking is the main puzzle system.

Each legitimate agent has a small set of facts the player can verify. No individual check is perfectly reliable.

A caller may pass some checks and fail another:

| Check | Example |
| --- | --- |
| Callsign | ECHO-2 |
| Frequency | Assigned to 104.7 MHz |
| Location | Last reported at Pump Station B |
| Challenge | "What walks home without feet?" |
| Response | Listed on the current authentication sheet |
| Context | Should know that ECHO-ACTUAL changed route five minutes ago |
| Behavior | Uses a particular phrase or radio habit |

Early calls teach the player how normal agents behave.

Later, the ghost starts learning.

An old authentication code may no longer prove anything.

## Sacrifice: burning a channel

The strongest defensive action is to **burn** a radio channel.

Burning a channel:

- permanently disables that frequency for the rest of the run;
- immediately stops transmissions coming through it;
- prevents the ghost from continuing to use that route;
- may permanently strand a legitimate field agent.

This is intentionally irreversible.

The player should sometimes have enough evidence to be suspicious, but not enough to be certain.

## The ghost

The ghost should not behave like a conventional monster.

Its progression is primarily informational:

### 1. Interference
Unexpected static, drift, overlapping transmissions, malformed identifiers.

### 2. Impossible knowledge
A caller knows something they should not know, or reports an event before another agent reports it happening.

### 3. Impersonation
A second transmission uses a real agent's voice and callsign.

### 4. Learning
The ghost begins answering authentication challenges correctly using information heard earlier in the shift.

### 5. Machine intrusion
The radio, procedural monitor, printer, indicators, or other station equipment begins producing information without a legitimate source.

The player should eventually distrust not only the callers, but the machine used to verify them.

## Scope

Target: a **20–30 minute complete jam game**.

### In scope

- one small 3D communications room;
- seated or tightly constrained first-person interaction;
- one visible rigged player arm;
- one primary radio receiver;
- one procedurally rendered monitor/spectrum display;
- a small set of physical papers and authentication sheets;
- two legitimate field agents;
- one impersonating entity;
- a handful of scripted transmissions;
- branching consequences;
- 2–3 endings;
- radio tuning;
- identity verification;
- challenge-response riddles;
- irreversible channel sacrifice;
- escalating environmental anomalies.

### Out of scope

- open-world exploration;
- combat;
- complex NPC simulation;
- procedural campaign generation;
- large inventories;
- free-form dialogue AI;
- many radio stations;
- elaborate character animation;
- multiple large environments;
- a long campaign.

The jam version should prioritize one polished scenario over breadth.

## Visual direction

The room is modeled in Blender using simple geometry and mostly flat/basic colors.

The visual target is a stylized, readable operations room rather than photorealism:

- simple low-poly equipment;
- strong silhouettes;
- restrained material variation;
- large readable knobs and switches;
- ordinary office colors;
- minimal environmental clutter;
- procedural CRT/spectrum graphics generated in code;
- diegetic UI wherever practical.

The room should initially feel mundane rather than threatening. Horror is introduced by behavior, sound, and small inconsistencies instead of filling the scene with conventional horror imagery.

The player's body is kept minimal. A single rigged arm provides physical interaction feedback without requiring a full first-person character.

## Audio and voices

Voice is one of the game's main assets.

Field-agent dialogue can be generated with lightweight/offline TTS and cached as authored lines. Runtime generative dialogue is not required.

Voice processing should sell the radio more than the raw TTS model:

```
voice
  -> EQ / band limiting
  -> compression
  -> light saturation
  -> radio static
  -> signal-strength degradation
  -> occasional dropout
```

Each agent should have a recognizable voice profile and speech habits.

The ghost should initially use the **same voice processing and voice identity as the person it copies**. Obvious "demon voice" effects would undermine the verification mechanic.

## Interaction

PC-first controls should be direct and fast:

- **Mouse** — look / interact
- **LMB** — use control / select
- **Drag** — rotate tuning knobs or sliders
- **Mouse wheel** — fine tune focused controls
- **Keyboard** — type terminal/authentication input
- **Push-to-talk key** — transmit or confirm a radio response

Common actions should become quick enough that the player feels increasingly competent at operating the station.

## Example encounter

ECHO-2 calls:

> "Operator, reached the east service room. Blue indicator above the door. Actual said proceed. Confirm."

Before the player replies, another frequency opens.

ECHO-ACTUAL warns:

> "Do not let Two enter anything marked blue."

A third channel activates.

It is also ECHO-ACTUAL.

> "Ignore previous. Two is clear to proceed."

The second ECHO-ACTUAL knows the correct callsign and sounds identical.

The player requests authentication.

It answers correctly — but with the answer from an obsolete challenge sheet.

The player now has to decide whether to trust the first voice, trust the second, hold ECHO-2 in place, or burn the suspicious channel completely.

That decision changes what happens next.

## Design principles

- **The radio work must be fun before the horror starts.**
- **Identity is inferred from evidence, not exposed by a UI meter.**
- **Wrong decisions should alter the story rather than immediately cause a game over.**
- **The ghost breaks learned rules gradually.**
- **No mechanic exists only because it satisfies a jam modifier.**
- **Use ambiguity instead of jumpscare frequency.**
- **Keep the entire experience feasible within one week.**

## Development priorities

For the jam build:

1. Build and light the room.
2. Implement looking, interaction, and the rigged arm.
3. Implement radio tuning and procedural spectrum/CRT rendering.
4. Build the transmission scripting system.
5. Implement papers and identity verification.
6. Implement challenge-response riddles.
7. Implement accept/reject/relay/burn decisions.
8. Add TTS voice lines and radio DSP.
9. Script the full 20–30 minute escalation.
10. Polish sound, feedback, endings, and build stability.

If scope becomes a problem, reduce the number of transmissions before reducing the depth of identity verification.

## Game jam

Created for **v3Expo's Game Jam 2**.

- **Theme:** The Ghost in the Machine
- **Jam period:** October 4–10, 2026
- **Required modifiers:** Settings Not Fit for Horror, Sacrifice Mechanics, Riddles

Final visual assets are intended to be authored directly rather than generated as AI art.

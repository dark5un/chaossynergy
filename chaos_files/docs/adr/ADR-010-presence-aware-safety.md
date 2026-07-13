# ADR-010: Visual Context for Agent-Human Pairing

## Status

Proposed

## Context

When two developers pair remotely, a huge amount of communication happens through the camera. The head-nod of understanding. The brow-furrow of confusion. The lean-back of deep thought. The eye-glaze of fatigue. A good pair reads these signals without thinking and adjusts naturally — rephrases, slows down, asks "does that make sense?", or just waits.

An AI agent paired with a human has none of that bandwidth. It only has text. It delivers the same response whether you are nodding along or silently horrified by what it just generated. It pings you with suggestions while you are deep in reading. It cannot tell when you walked away from the keyboard.

This is not just missed context. It is a safety gap. If the agent receives an instruction while no one is at the desk — a stray keystroke, a scroll-wheel click on a suggested command, a misunderstanding from an earlier turn — it could execute destructive operations with no one to verify.

## Decision

Create an opt-in sensing service called `chaossynergy-sense` that uses the camera to give the agent the same non-verbal bandwidth a human pair would have naturally. The service offers three fidelity tiers, each adding more context:

### Tier 1: Presence (safety gate)

The camera checks for a face at configurable intervals. If no face is detected for a timeout (default 30 seconds), the agent enters **deferred mode**:

- Destructive commands (write, delete, install, reboot, system modifications) are queued, not executed
- The agent responds: "I will run this when you are back at your desk"
- On return, the agent announces pending deferred commands for confirmation
- The user controls what operations require presence via `~/.chaossynergy/sense.yaml`

This is a **safety layer**, same category as the recovery shell and the distrobox isolation.

### Tier 2: Gaze (attention awareness)

When the user is present, head pose estimation determines screen attention:

- Looking at screen: normal operation, proceed with responses
- Not looking at screen: likely reading, thinking, or looking away. Agent waits for an explicit query before offering output
- This prevents the agent from flooding the user with output while they are reading documentation or thinking through a problem

### Tier 3: Expression (interaction dynamics)

When the user is present and looking at the screen, lightweight expression classification (7 basic categories: neutral, happy, surprised, confused, frustrated, sad, skeptical) can help the agent calibrate its communication:

- User looks confused at a response: agent offers "Let me explain that differently" or asks clarifying questions
- User looks frustrated at generated code: agent suggests reverting or trying another approach
- User looks happy or satisfied: agent reinforces what worked
- User smiles in the morning: agent greets with a tone that matches

This mirrors what a human pair does naturally. You see your partner's face and you adjust.

### What this is NOT

- **Not surveillance.** No video recording. No persistent images. No history log. No telemetry. The system has no network capability — it cannot send data anywhere.
- **Not facial recognition.** The system does not identify who is at the desk. It detects a face, estimates gaze direction, and optionally classifies expression into broad categories. No identity, no fingerprinting.
- **Not required.** Every tier is optional and independently configurable. The system works perfectly without any of it.

### Privacy model

| Aspect | Guarantee |
|--------|-----------|
| **Locality** | Everything runs on-device. Zero network requests. No cloud dependency. No third-party service. |
| **No recording** | Frame is read into memory, processed, discarded. No video stream, no snapshots, no buffers. |
| **No persistence** | Zero frames written to disk. The only output is the current state JSON (face count, gaze direction, mood label). |
| **Opt-in** | Disabled by default. User must explicitly enable it. |
| **Visual indicator** | Ptyxis terminal border or GNOME top-bar indicator when the camera is active. |
| **Data retention** | Only the last state snapshot is kept. No history. No logs. No telemetry. |
| **Configurable fidelity** | User chooses minimal / aware / full. Never more than what was opted into. |

### Configuration

```yaml
# ~/.chaossynergy/sense.yaml
mode: minimal              # minimal | aware | full
timeout: 30                # seconds before defer mode activates
device: /dev/video0        # camera device
```

- **minimal** — presence only. Safety gate for deferred commands. No gaze, no expression.
- **aware** — presence + gaze. Agent times responses to user attention.
- **full** — presence + gaze + expression. Agent reads interaction dynamics for natural pairing.

## Rationale

- The pair programming analogy is the closest model for human-agent collaboration. An agent that cannot see the user is a pair programmer wearing a blindfold. It can still work, but it misses half the conversation.
- Presence-aware safety is the most concrete and universal benefit. It prevents a class of accidents that no other isolation layer can address.
- Gaze and expression awareness are about communication quality, not surveillance. They let the agent calibrate its pacing and tone the way a human pair naturally would.
- Running everything locally guarantees privacy by architecture, not by policy. No data ever leaves the machine.
- Opt-in with tiered fidelity lets each user choose their comfort level. Minimal is a safety feature everyone can agree on. Full is for users who want the richest pairing experience.

## Technical approach

1. **MediaPipe Face Detection** — lightweight on-device ML. Returns presence boolean + face count. ~5ms on CPU.
2. **MediaPipe Face Mesh** (468 landmarks) — head pose estimation for gaze direction. ~15ms on CPU.
3. **Expression classifier** — tiny ONNX model (MobileNet on FER2013, ~5MB). 7 broad categories. ~10ms on CPU.
4. **Polling intervals** — presence every 5s, gaze every 5s, expression every 30s (slow-changing signal).
5. **Resource impact** — ~3-5% CPU, ~500MB RAM for the full stack.

## Alternatives considered

- **No camera** — simplest. The agent stays blind to user state. Acceptable for many. Leaves the safety gap open and the pairing channel silent.
- **Keyboard/mouse activity** — Passive idle detection. Cannot distinguish "reading" from "away." Not reliable enough for a safety gate.
- **Cloud APIs** (Google, Azure) — violates the local-first principle. Data leaves the machine. Not acceptable for Chaossynergy.
- **Facial recognition** (identify *who*) — out of scope. Violates the privacy model.

## Consequences

**Positive:**
- Agent defers dangerous commands when no one is at the desk (safety gate)
- Agent can time its communication to the user's attention state
- Richer human-agent interaction through non-verbal feedback
- Fully private by architecture — no data leaves the machine
- Each user controls exactly how much bandwidth they give the agent

**Risks:**
- MediaPipe packages add ~300MB to the agent container image
- Camera may not be present on desktop machines — service degrades gracefully to no-op
- Some users will never enable it on principle. That is fine — it is opt-in.
- False negatives (camera misses the user) can cause unnecessary deferrals. Configurable timeout and sensitivity mitigate this.
- The expression classifier is a broad heuristic, not a mind reader. It will be wrong sometimes. The agent must treat it as a hint, not a fact.

## References

- https://github.com/google/mediapipe
- [The look of frustration: why face reading matters in pairing](https://www.researchgate.net/publication/220982999_Automatic_prediction_of_frustration)
- ADR-005: Minimal host, container-first
- ADR-008: Desktop experience — GNOME autostart
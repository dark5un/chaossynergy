# ADR-010: Presence-Aware Safety via Camera

## Status

Proposed

## Context

Remote pair programming has a well-known problem. When both developers keep their cameras on, communication is richer. You see the head-nod of understanding, the brow-furrow of confusion, the lean-back of "let me think about this." When the cameras are off, you lose that channel entirely.

An AI agent working alongside you has the same blind spot. It only has your text. It cannot tell if you are at your desk, if you walked away mid-session, or if you are deep in thought and should not be interrupted.

This is not just a communication problem. It is a **safety** problem.

Chaossynergy gives the agent elevated access: distrobox with `--privileged`, access to the home directory, ability to run commands, write files, and interact with the system. If the agent receives an instruction while the user is not present — a stray keystroke, a leftover command in the buffer, a misunderstanding from an earlier turn — it could execute destructive operations with no one to verify.

The opening paragraph of a prompt or a hallucinated "rm -rf /" in a code suggestion should not be acted on when the user walked away from the keyboard fifteen minutes ago.

## Decision

Create a lightweight sensing service called `chaossynergy-presence` that uses the camera **only** for binary presence detection. The service answers one question: is there a person at the desk right now?

### Primary use case: presence gate

If the camera detects no face for a configurable timeout (default 30 seconds), the agent enters a **deferred mode**:

- Commands that modify the system (write, delete, install, reboot) are queued, not executed
- The agent responds with: "I will run this when you are back at your desk"
- When the user returns, the agent announces pending deferred commands for confirmation
- This applies to any tool or operation the user configures as requiring presence

This is a **safety layer**, same category as the recovery shell and the distrobox isolation. It does not prevent the user from working. It prevents the agent from acting when no one is watching.

### Secondary: awareness hints

When the user is present, the camera can provide lightweight context that mirrors what a human pair would see naturally:

| Signal | What it means | How the agent uses it |
|--------|---------------|----------------------|
| User at desk | Present, available | Normal operation |
| User steps away | Away from keyboard | Defer dangerous commands |
| User looking at screen | Engaged | Proceed with responses |
| User not looking at screen | Reading, thinking | Wait for explicit query |
| Multiple faces detected | Meeting, call | Defer all non-urgent output |

These are hints, not commands. The agent never acts on them autonomously — they only adjust *when* and *how* the agent communicates, not *what* it does.

### What this is NOT

- **Not surveillance.** No video recording. No persistent images. No history log. Frames are read into memory, processed for face landmarks, and discarded.
- **Not facial recognition.** The system does not identify who is at the desk. It only detects whether a face is present.
- **Not emotion analysis.** No attempt to read mood, sentiment, or emotional state. That is a separate feature if someone explicitly wants it.
- **Not required.** The service is opt-in, disabled by default. If the camera is absent or the user does not enable it, the service degrades gracefully to no-op and the agent operates without presence awareness.

### Privacy model

| Aspect | Implementation |
|--------|----------------|
| No video recorded | Frame read into memory, processed, discarded immediately |
| No persistent images | Zero frames written to disk unless explicit debug mode enabled |
| Opt-in | Disabled by default. Enable via `chaossynergy-presence enable` |
| Visual indicator | Ptyxis terminal border or GNOME indicator when camera is active |
| Data retention | Only the last presence state kept. No history. No logs. |

### Technical approach

1. **MediaPipe Face Detection** — lightweight, on-device, no GPU needed. Detects whether a face is in frame. Returns presence boolean + face count.
2. **Gaze estimation** (optional) — MediaPipe Face Mesh (468 landmarks). Determines head pose angles to estimate screen attention. Useful for "looking at screen vs reading a book" distinction.
3. **Polling interval** — 5 seconds for presence, 5 seconds for gaze (if enabled). Low CPU impact (~3-5% of one core).

### Profile system

Users who want more can configure a profile:

```
# ~/.chaossynergy/presence.yaml
mode: minimal           # minimal | aware | full
timeout: 30             # seconds before defer mode
device: /dev/video0     # camera device
```

- **minimal** — presence only (default when enabled)
- **aware** — presence + gaze estimation
- **full** — presence + gaze + emotion (only if someone explicitly opts in)

## Alternatives considered

- **No camera at all** — simplest. The agent stays blind to user presence. Acceptable for many users, but leaves the safety gap open.
- **Keyboard/mouse activity monitor** — Passive, no camera needed. Detects idle time. Cannot distinguish "user at desk reading" from "user walked away" — both look like inactivity. Not reliable enough for a safety gate.
- **Ultrasonic/bT presence** — External sensors. Not portable, not available on every laptop.
- **Facial recognition** — Identifies *who* is present. Out of scope. Violates the privacy principle.

## Rationale

- A camera is present on almost every laptop. It is the most universal presence sensor available.
- Face detection with MediaPipe runs in ~10ms on CPU with minimal power draw. No cloud, no latency.
- The pair programming analogy is the closest model for what we are building. An agent that cannot see you misses what a human pair would pick up naturally. The camera fills that gap.
- Presence-aware safety is a concrete, practical feature. It prevents a class of accidents that no other isolation layer addresses.
- Users who do not want camera access can simply not enable it. The system works fine without it — presence awareness is a safety upgrade, not a dependency.

## Consequences

**Positive:**
- Agent defers dangerous commands when no one is at the desk
- The safety model gains a human-aware layer beyond bootc and distrobox
- Agent can time interruptions naturally (no pings when you are reading or on a call)
- Removes the "creepy" factor by being explicit about what it does and does not do

**Risks:**
- Some users will never enable it due to principle. That is acceptable — it is opt-in.
- False negatives (camera misses the user) can cause unnecessary deferrals. Configurable timeout mitigates this.
- False positives (cat walks past, triggers presence) are harmless — presence is permissive, absence is restrictive.
- MediaPipe Python packages are large (~300 MB). Trade-off for on-device ML.

## References

- https://github.com/google/mediapipe
- https://github.com/ShubhamBhatti-01/Facial-Expression-Recognition
- ADR-005: Minimal host, container-first
- ADR-008: Desktop experience — GNOME autostart
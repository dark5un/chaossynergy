# ADR-010: Environment Sensing via Camera

## Status
Proposed

## Context
An agent that cannot perceive its user's state is blind. Chaossynergy should
know when the user is present, their attention level, and basic environmental
context — not as surveillance, but as input for more natural agent behavior.

Examples:
- DND activates when user is on a call (multiple faces detected)
- Agent defers notifications when user looks away or is reading
- Morning greeting when user sits down after absence
- Prompt enrichment: "The user appears tired after 4 hours of continuous work"

Requirements:
- Fully local, no cloud
- No video recording, no persistent images
- Privacy-first: explicit opt-in, clear indicator when camera is active
- Runs as a background service inside the agent distrobox
- Outputs structured JSON consumed by Hermes

## Decision

Create a small Python sensing service called `chaossynergy-sense` that runs as a
herdr background pane or user systemd service. It polls the camera at
configurable intervals using MediaPipe for lightweight on-device ML.

### Architecture

```
/dev/video0
    │
    ▼
  OpenCV (frame capture)
    │
    ├────────────────────────────────┐
    ▼                                ▼
MediaPipe Face Detection      MediaPipe Face Mesh
    │                                │
    ▼                                ▼
  presence.json (bool)          gaze.json (looking_at_screen, eye_openness)
                                    │
                                    ▼
                              emotion.onnx (tiny, 5MB, FER2013)
                                    │
                                    ▼
                              emotion.json
                                    │
                                    ▼
                          ~/.chaossynergy/sense/context.json
                                    │
                                    ▼
                            Hermes reads into prompt
```

### Components

1. **Frame capture** — OpenCV reads from `/dev/video0`, configurable device.
   Frame grabbed, processed, discarded. No video stream kept.

2. **Presence detection** — MediaPipe Face Detection. Binary output: face or no
   face. Used to track desk occupancy, trigger events on absence/return.

3. **Gaze estimation** — MediaPipe Face Mesh (468 landmarks). Head pose angles
   (yaw/pitch/roll) determine if user is looking at the screen. Eye landmark
   distances determine eye openness (attentive vs closed/drowsy).

4. **Emotion classification** — A tiny ONNX model (MobileNet or MiniXception
   trained on FER2013, ~5MB). 7 classes: angry, disgust, fear, happy, neutral,
   sad, surprised. Runs in ~10ms on CPU.

5. **State file** — JSON written to `~/.chaossynergy/sense/context.json`:
```json
{
  "present": true,
  "since": "2026-07-12T09:15:00Z",
  "gaze": {"looking_at_screen": true, "eye_openness": 0.85},
  "emotion": {"primary": "neutral", "confidence": 0.72},
  "faces": 1,
  "ambient": {"lighting": "normal"}
}
```

6. **Hermes integration** — Hermes reads the context file and includes it as a
   natural-language prefix: `[User context: present, neutral mood, looking at
   screen, been at desk for 47 minutes]`

### Privacy model

| Aspect | Implementation |
|--------|----------------|
| No video recorded | Frame is read into memory, processed, discarded immediately |
| No persistent images | No frames written to disk unless debug mode is explicitly enabled |
| Opt-in | Service is disabled by default. User enables via `chaossynergy-sense enable` |
| Visual indicator | Ptyxis terminal border or GNOME indicator when camera is active |
| Data retention | Only the last context.json is kept. No history log |

### Polling intervals

| Metric | Interval | Rationale |
|--------|----------|-----------|
| Presence | 5 seconds | Fast enough to catch absence/return |
| Gaze | 5 seconds | Tied to presence check |
| Emotion | 30 seconds | Emotion is slow-changing, no need for faster |
| Full description | 60 seconds | Vision model runs for scene description |

### Resource impact

- CPU: ~3-5% of one core during inference
- RAM: ~500 MB for MediaPipe + OpenCV + model
- Disk: ~500 MB for Python packages + models
- Camera: flashes once per interval (typical laptop IR or webcam)

### Implementation plan

1. Install Python packages: `mediapipe`, `opencv-python`, `numpy`, `onnxruntime`
2. Create `/usr/local/bin/chaossynergy-sense` — Python service
3. Create systemd user service `chaossynergy-sense.service`
4. Create `~/.chaossynergy/sense/config.yaml` for user settings
5. Hermes reads `context.json` via a prompt hook or MCP tool

## Consequences

Positive:
- Hermes knows if you're at the desk, without asking
- Agent can defer interruptions when you're reading or on a call
- Privacy-first design avoids surveillance concerns
- Enables future features: presence-based lock/unlock, adaptive notifications

Risks:
- Creepy if not transparent — MUST have clear opt-in and visible indicator
- MediaPipe packages are large (~300 MB Python + models)
- Webcam may not be present (desktops) — service degrades gracefully to no-op
- Some users will never enable this — OK, it's optional

## References
- https://github.com/google/mediapipe
- https://github.com/serengil/deepface (alternative, heavier)
- https://github.com/ShubhamBhatti-01/Facial-Expression-Recognition (FER2013 model)
- GNOME 50 camera indicator API (privacy indicator in top bar)

## Alternatives considered

- **Facial recognition** (identify *who*) — out of scope, violates privacy principle
- **OpenCV Haar cascades** — dated, lower accuracy than MediaPipe
- **DeepFace** — heavier, includes recognition, too much for this use case
- **Audio presence** (mic energy detection) — supplements camera, less precise
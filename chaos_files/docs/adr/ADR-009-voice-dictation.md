# ADR-009: Local Voice Dictation

## Status
Proposed

## Context
Chaossynergy is an agent-first OS. Voice is the most natural input modality after
text. The user should be able to press a key, speak, and have their words
transcribed instantly into any application — terminal, browser, editor.

Requirements:
- Fully local, no cloud dependency
- Push-to-talk via a configurable hotkey
- Output as typed text into the active application (not a separate window)
- Works offline
- Acceptable accuracy for coding terms and technical vocabulary

## Decision

Use **Whisper.cpp** (ggerganov/whisper.cpp) as the speech recognition engine,
running as a lightweight streaming service inside the agent distrobox. Trigger
via herdr keybinding or a GNOME custom shortcut.

### Architecture

```
Hotkey (Super+Space)
     │
     ▼
  arecord / ffmpeg    ← captures microphone via ALSA/PulseAudio
     │
     ▼
  whisper.cpp stream  ← runs ggml-tiny (1GB) or ggml-small (3GB)
     │                  fully local, CPU only, no GPU needed
     ▼
  wtype / ydotoool    ← types transcribed text into active window
```

### Components

1. **whisper.cpp** — compiled C++ inference engine. Stream mode processes audio
   in chunks, returning partial transcripts in real-time with low latency.
2. **Audio capture** — `parecord` from PulseAudio (or `pw-record` for PipeWire),
   captures from the default input device when triggered.
3. **Typing output** — `wtype` (wlroots) or `ydotool` (generic) sends keystrokes
   to the focused application. Available in most distros.
4. **Orchestrator script** — Python or bash script that:
   - Listens for hotkey press
   - Starts audio capture + whisper stream
   - Pipes transcribed text to `wtype`
   - Stops on hotkey release

### Model selection

| Model | Size | RAM | Accuracy | Latency |
|-------|------|-----|----------|---------|
| ggml-tiny | ~1 GB | ~2 GB | Good | ~1s |
| ggml-small | ~3 GB | ~4 GB | Very good | ~2s |
| ggml-base | ~1.5 GB | ~2.5 GB | Better | ~1.5s |

`ggml-tiny` is the default. User can upgrade by downloading a larger model.

### Privacy

- Zero network requests
- Models cached locally in `~/.cache/whisper.cpp`
- Audio buffer held in memory only during recording, discarded immediately
- No audio files written to disk unless user explicitly opts to log

### Implementation plan

1. Add `whisper.cpp` to the agent container Dockerfile (build from source)
2. Pre-download `ggml-tiny` model (~1 GB) during container build
3. Create orchestrator script at `/usr/local/bin/chaossynergy-dictate`
4. Bind hotkey via herdr config or GNOME settings
5. Test: press hotkey → speak → text appears in terminal

## Consequences

Positive:
- Natural, fast input for coding, searching, and commanding
- Fully private, offline, no API costs
- Works alongside Hermes chat — speak a command, agent executes it

Risks:
- ~1 GB additional image size for the model
- whisper.cpp takes ~20 seconds to compile from source (or pre-built binary)
- Microphone permissions on Wayland require PipeWire or PulseAudio
- Accuracy on technical jargon (Rust, Kubernetes) benefits from the larger model

## References
- https://github.com/ggerganov/whisper.cpp
- https://github.com/atareao/voice-typing (GNOME extension, cloud-based)
- https://weread.tech/ (whisper streaming server)

## Alternatives considered

- **GNOME built-in dictation** (Super+H) — cloud-dependent, low accuracy, no control
- **VoiceInk extension** — Whisper backend, but extension API is fragile
- **Vosk** — older models, lower accuracy than Whisper
- **Cloud APIs** (Google, Azure) — violates local-first principle
# ADR-011: Local Inference Runtime

**Status:** Draft
**Date:** 2026-07-13
**Author:** Panagiotis Xynos (Master) / OrsonRius (Padawan)

## Context

Chaossynergy is an agent-native operating system. Currently, all agent inference happens through remote API providers (OpenRouter, Anthropic, OpenAI, etc.). This creates several limitations:

- **Offline dependency** — the agent is non-functional without internet access
- **Latency** — every inference round-trip crosses the network, even for trivial operations
- **Privacy** — codebases, documents, and prompts leave the machine
- **Cost** — per-token billing accumulates with heavy usage
- **Sovereignty** — the agent's intelligence is contingent on external services

The Chaossynergy host (Bluefin LTS) already ships with NVIDIA drivers pre-baked (per ADR-001). The current hardware is an RTX 5090 with 32 GB VRAM and 125 GB system RAM — more than capable of running local inference for models up to ~27B parameters at useful quantization levels.

ADR-004 established the multi-agent architecture with isolated distrobox containers. This ADR extends that pattern to add a dedicated inference runtime as a sibling container that Hermes and other agents can connect to via an OpenAI-compatible API.

## Decision 1: Both llama.cpp and vLLM

**Decision:** Install and maintain both inference engines in the inference container.

- **llama.cpp** — the universal Swiss Army knife. Single binary, zero Python dependencies, CPU+GPU hybrid, supports any GGUF model from Hugging Face. Installed via `brew install llama.cpp` or direct binary download. Used for ad-hoc inference, model discovery, quick experiments, and CPU fallback when GPU memory is exhausted.

- **vLLM** — the production serving engine. PagedAttention, continuous batching, tensor parallelism, FP8/AWQ/GPTQ quantization. Python-based, pip-installable. Used for persistent serving of a primary model as an OpenAI-compatible endpoint that Hermes connects to as a custom provider.

**Alternatives considered:**

| Alternative | Rationale for rejecting |
|-------------|------------------------|
| **llama.cpp only** | No continuous batching, lower throughput for multi-request scenarios. Fine for single-user but limits future use cases (e.g., batch code review). |
| **vLLM only** | Python-heavy, no CPU fallback, requires more setup. Not suitable for quick model discovery or when GPU is busy. |
| **Ollama** | Adds another abstraction layer. Less control over server configuration (port, context length, GPU layers). llama.cpp is Ollama's backend anyway — we can use it directly. |
| **Text-Generation-Inference** | HuggingFace's serving stack. Heavier, less flexible with GGUF, tied to HF ecosystem. |
| **TensorRT-LLM** | NVIDIA-only, maximum performance but significantly more complex to set up and maintain. Overkill for the prototype. |

**Rationale:**

Both engines serve different roles and complement each other:

- llama.cpp is the **discovery and fallback engine** — instant startup, any GGUF model, works on CPU alone. When you want to try a new model, you download the GGUF and run `llama-server -hf repo:quant` in seconds. When the GPU is busy with vLLM, llama.cpp can run on CPU with partial offload.

- vLLM is the **production serving engine** — once we settle on a default model (e.g., ThinkingCap-Qwen3.6-27B), vLLM serves it with continuous batching, prefix caching, and high throughput. Hermes connects to it as a custom provider via the OpenAI-compatible API.

- The combined disk footprint (~2 GB for both) is negligible compared to the model files themselves (16-22 GB for a quantized 27B).

## Decision 2: Dedicated Inference Distrobox

**Decision:** The inference runtime runs in its own distrobox container, not in the Hermes agent container and not on the host.

**Alternatives considered:**

| Alternative | Pros | Cons |
|-------------|------|------|
| **Host image (pre-baked)** | Available to all containers, NVIDIA drivers co-located | Bloats the OS image, contradicts "minimal host" (ADR-005), harder to update independently |
| **Hermes distrobox (co-located)** | Simple mental model, follows existing pattern | Swells the agent container (~2 GB extra), memory sharing with Hermes, hard to restart independently |
| **Dedicated inference distrobox (chosen)** | Clean isolation, independently restartable, doesn't bloat the agent, scales to multiple models | Another container to manage, extra RAM for the container itself |

**Rationale:**

- Per ADR-004, each agent gets its own distrobox with full isolation. The inference engine is a service agent — it serves models, not users.
- The inference container can be stopped and restarted independently without affecting the Hermes session.
- We can run multiple inference containers with different models (e.g., one for coding, one for chat) without conflicts.
- The NVIDIA GPU is accessible from any distrobox container via the host's NVIDIA drivers and `--device nvidia.com/gpu=all`.
- Container overhead is minimal (~100 MB for the base image + inference engine binaries).

### Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Bluefin LTS Host                                        │
│  ┌────────────────────────────────────────────────────┐  │
│  │  herdr (terminal multiplexer)                      │  │
│  │  ┌──────────────┐  ┌───────────────────────────┐   │  │
│  │  │ Workspace:   │  │ Workspace: inference      │   │  │
│  │  │ local-cloud  │  │                           │   │  │
│  │  │              │  │ No TUI — runs as systemd   │   │  │
│  │  │ Hermes       │  │ service in background      │   │  │
│  │  │ (orch.)      │  │                           │   │  │
│  │  └──────┬───────┘  └───────────────────────────┘   │  │
│  │         │ connects to                               │  │
│  │         │ http://10.0.2.2:8080/v1                   │  │
│  │         │                                           │  │
│  │         ▼                                           │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │ Distrobox: inference                          │   │  │
│  │  │ ┌──────────────┐  ┌────────────────────────┐ │   │  │
│  │  │ │ llama-server  │  │ vllm serve (optional)  │ │   │  │
│  │  │ │ :8080         │  │ :8000                  │ │   │  │
│  │  │ │ GGUF models   │  │ safetensors models     │ │   │  │
│  │  │ └──────────────┘  └────────────────────────┘ │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └────────────────────────────────────────────────────┘  │
│                                                            │
│  NVIDIA RTX 5090 (32 GB VRAM)                              │
│  Shared across all containers via nvidia-container-toolkit │
└──────────────────────────────────────────────────────────┘
```

## Decision 3: Default Model — ThinkingCap-Qwen3.6-27B

**Decision:** The default model for the inference container is `bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF` at Q4_K_M quantization.

**Rationale:**

- 27B parameters at Q4_K_M ≈ 16-18 GB VRAM — fits comfortably in the RTX 5090's 32 GB with room for KV cache (8-12 GB for 32K context)
- Qwen3.6 base is a strong general-purpose model with good coding and reasoning capabilities
- The "ThinkingCap" fine-tune adds Chain-of-Thought / reasoning enhancements
- 315K downloads on HF Hub — proven community adoption
- GGUF format is native to llama.cpp and can be used immediately without conversion
- If the user has a different preference, the model is configurable via `inference.yaml`

**Alternatives considered:**

| Model | Size | Memory | Rationale for not choosing as default |
|-------|------|--------|---------------------------------------|
| Llama 3.2 3B | 3B | ~2 GB | Too small for serious coding work |
| Qwen2.5-Coder-7B | 7B | ~5 GB | Good coding model, but smaller than what the hardware can handle |
| DeepSeek-Coder-V2-16B | 16B | ~10 GB | Excellent coder, but 27B is feasible and offers more reasoning |
| ThinkingCap-Qwen3.6-27B | 27B | ~16-18 GB | Chosen — best fit for hardware capability |
| Llama 3.3 70B | 70B | ~40 GB (Q4) | Won't fit in 32 GB VRAM without offloading to CPU (slow) |

## Decision 4: Mutual Exclusivity — One Engine at a Time

**Decision:** llama.cpp and vLLM are mutually exclusive. Only one inference server runs at a time. Switching engines stops the other.

This is a practical constraint — both engines compete for GPU VRAM. The 27B model at Q4_K_M uses ~16 GB, leaving ~16 GB for KV cache on a 32 GB card. Running both simultaneously would OOM.

The user picks an engine at setup time:

| Command | Engine | Install | Port |
|---------|--------|---------|------|
| `ujust setup-inference-llama` | llama.cpp | `curl ... https://llama.app/install.sh \| sh` | 8080 |
| `ujust setup-inference-vllm` | vLLM | `pip install vllm` | 8000 |

Both commands are idempotent. Running one stops and disables the other's systemd user service. The inference distrobox is shared — only the service file differs.

### Hermes Provider Configuration

Each engine configures its own Hermes custom provider:

```yaml
# llama.cpp (via ujust setup-inference-llama)
providers:
  custom:
    local-llama:
      base_url: "http://127.0.0.1:8080/v1"
      models:
        - "bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q4_K_M"
        - "bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q8_0"

# vLLM (via ujust setup-inference-vllm)
providers:
  custom:
    local-vllm:
      base_url: "http://127.0.0.1:8000/v1"
      models:
        - "bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF"
```

The user switches between remote and local models:

```bash
hermes model set custom:local-llama/bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q4_K_M
hermes model set custom:local-vllm/bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF
```

## Implementation Plan

The guiding principle: **setup via ujust at user request, runtime via systemd user service for persistence.** Herdr doesn't care how the inference server was started — it just connects to the endpoint.

### Phase 1: ujust Recipes

A `chaossynergy.just` file ships in the image at `/usr/share/ublue-os/just/` and is auto-discovered by Bluefin's `ujust`:

```make
# ── Inference setup ────────────────────────────────────

setup-inference-llama:
    # Creates or reuses the inference distrobox
    @test -n "$(distrobox list | grep inference)" || \
      distrobox create --name inference \
        --image quay.io/fedora/fedora:latest \
        --additional-flags "--device nvidia.com/gpu=all -p 8080:8080"
    # Installs the llama CLI (single binary, auto-downloads models)
    distrobox enter inference -- \
      curl -LsSf https://llama.app/install.sh | sh
    # Creates systemd user service with llama serve -hf
    systemctl --user stop chaossynergy-vllm 2>/dev/null || true
    systemctl --user disable chaossynergy-vllm 2>/dev/null || true
    @cat > ~/.config/systemd/user/chaossynergy-inference.service << 'SERVICE'
[Unit]
Description=Chaossynergy Local Inference (llama.cpp)
After=network.target
[Service]
Environment=HOME=/root
ExecStart=/usr/bin/distrobox enter inference -- bash -c \
  'export PATH=$HOME/.local/bin:$PATH && exec llama serve \
   -hf bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q4_K_M \
   --host 0.0.0.0 --port 8080 -ngl 99 -c 32768'
Restart=on-failure
[Install]
WantedBy=default.target
SERVICE
    systemctl --user daemon-reload
    systemctl --user enable --now chaossynergy-inference.service
    # Configures Hermes
    distrobox enter agent -- hermes config set \
      providers.custom.local-llama.base_url "http://127.0.0.1:8080/v1"
    distrobox enter agent -- hermes config set \
      providers.custom.local-llama.models \
      '["bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q4_K_M",
        "bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q8_0"]'

setup-inference-vllm:
    # Creates or reuses the inference distrobox
    @test -n "$(distrobox list | grep inference)" || \
      distrobox create --name inference \
        --image quay.io/fedora/fedora:latest \
        --additional-flags "--device nvidia.com/gpu=all -p 8000:8000"
    # Installs Python + vLLM
    distrobox enter inference -- \
      dnf install -y python3-pip && pip install --upgrade pip && pip install vllm
    # Stops llama, creates vLLM service
    systemctl --user stop chaossynergy-inference 2>/dev/null || true
    systemctl --user disable chaossynergy-inference 2>/dev/null || true
    @cat > ~/.config/systemd/user/chaossynergy-vllm.service << 'SERVICE'
[Unit]
Description=Chaossynergy Local Inference (vLLM)
After=network.target
[Service]
ExecStart=/usr/bin/distrobox enter inference -- \
  vllm serve "bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF" --port 8000
Restart=on-failure
[Install]
WantedBy=default.target
SERVICE
    systemctl --user daemon-reload
    systemctl --user enable --now chaossynergy-vllm.service
    # Configures Hermes
    distrobox enter agent -- hermes config set \
      providers.custom.local-vllm.base_url "http://127.0.0.1:8000/v1"
    distrobox enter agent -- hermes config set \
      providers.custom.local-vllm.models \
      '["bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF"]'
```

### Phase 2: Runtime Management

```make
inference-logs:
    journalctl --user -fu chaossynergy-inference 2>/dev/null || \
      journalctl --user -fu chaossynergy-vllm

inference-stop:
    systemctl --user stop chaossynergy-inference 2>/dev/null || \
      systemctl --user stop chaossynergy-vllm 2>/dev/null

inference-restart:
    systemctl --user restart chaossynergy-inference 2>/dev/null || \
      systemctl --user restart chaossynergy-vllm 2>/dev/null

inference-model:
    # Switch quant on llama.cpp (Q4_K_M / Q8_0)
    @read -p "Quant (Q4_K_M or Q8_0, default Q4_K_M): " quant; \
    quant="$${quant:-Q4_K_M}"; \
    systemctl --user stop chaossynergy-inference; \
    sed -i "s|-hf [^ ]*|-hf bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:$$quant|" \
      ~/.config/systemd/user/chaossynergy-inference.service; \
    systemctl --user daemon-reload; \
    systemctl --user start chaossynergy-inference
```

### Phase 3: No user-setup.sh Integration

The inference provider config is not added during first-boot setup. It's only added when the user runs `ujust setup-inference-llama` or `ujust setup-inference-vllm`. This keeps first-boot fast and avoids stale config pointing to a server that doesn't exist yet.

## Consequences

**Positive:**

- Hermes can operate fully offline for most tasks
- Code and data never leave the machine for local inference
- No per-token cost for local inference
- Sub-100ms time-to-first-token for small models, ~500ms for 27B
- The inference container is independently resettable
- Engine choice is user-driven, not baked into the image
- llama auto-downloads GGUFs from Hugging Face on first request — no separate model download step
- Switching quant (Q4_K_M ↔ Q8_0) is a single ujust command
- Only one engine uses VRAM at a time — no OOM conflicts

**Risks:**

- Model files consume 15-27 GB of disk (llama caches in ~/.llama/ or ~/.cache/)
- vLLM adds Python + CUDA dependencies (~2 GB in the container)
- Switching engines requires restarting the server (transient downtime)
- The user must accept the model's license terms before first use
- llama CLI install script requires internet access on first run
- vLLM needs Python/pip which adds build time to the container setup

## References

- [ADR-001](ADR-001-architecture-decisions.md) — Base image choice (NVIDIA drivers pre-baked)
- [ADR-004](ADR-004-multi-agent-architecture.md) — Multi-agent architecture with distrobox
- [ADR-005](ADR-005-minimal-host-container-first.md) — Minimal host, container-first
- [llama.cpp](https://github.com/ggml-org/llama.cpp) — GGUF inference engine (install via https://llama.app/install.sh)
- [vLLM](https://github.com/vllm-project/vllm) — High-throughput LLM serving
- [ThinkingCap-Qwen3.6-27B-GGUF](https://huggingface.co/bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF) — Default model
- [Hermes Custom Providers](https://hermes-agent.nousresearch.com/docs) — Custom provider configuration
- [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/index.html) — GPU sharing across containers
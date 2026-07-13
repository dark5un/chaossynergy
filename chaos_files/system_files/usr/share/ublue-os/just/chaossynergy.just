# ────────────────────────────────────────────────────────────
#  Chaossynergy — ujust recipes
#  Agent-native immutable Linux. Agents are the interface.
# ────────────────────────────────────────────────────────────
#  Loaded by ujust from /usr/share/ublue-os/just/
#  Run `ujust` to list all available recipes.
# ────────────────────────────────────────────────────────────

# ── Agent containers ───────────────────────────────────────
# Install a coding agent in its own distrobox container.
# Idempotent — skips if the container already exists.

setup-opencode:
    @test -n "$(distrobox list 2>/dev/null | grep opencode)" && echo "✓ OpenCode agent already exists" && exit 0
    @echo "Creating OpenCode distrobox..."
    distrobox create --name opencode --image quay.io/fedora/fedora:latest || exit 1
    distrobox enter opencode -- npm install -g opencode-ai@latest || exit 1
    distrobox enter opencode -- opencode auth list 2>/dev/null || echo "→ Run 'ujust setup-opencode-auth' to configure providers"
    @echo ""
    @echo "✓ OpenCode ready. Enter with: distrobox enter opencode"

setup-opencode-auth:
    @echo "Authenticating OpenCode..."
    distrobox enter opencode -- opencode auth login

setup-pi:
    @test -n "$(distrobox list 2>/dev/null | grep pi)" && echo "✓ Pi agent already exists" && exit 0
    @echo "Creating Pi distrobox..."
    distrobox create --name pi --image quay.io/fedora/fedora:latest || exit 1
    distrobox enter pi -- npm install -g @earendil-works/pi-coding-agent || exit 1
    @echo ""
    @echo "✓ Pi agent ready. Enter with: distrobox enter pi"

setup-claude:
    @test -n "$(distrobox list 2>/dev/null | grep claude)" && echo "✓ Claude Code agent already exists" && exit 0
    @echo "Creating Claude Code distrobox..."
    distrobox create --name claude --image quay.io/fedora/fedora:latest || exit 1
    distrobox enter claude -- npm install -g @anthropic-ai/claude-code || exit 1
    @echo ""
    @echo "✓ Claude Code ready. Enter with: distrobox enter claude"

setup-all-agents: setup-opencode setup-pi setup-claude
    @echo "✓ All coding agents installed"

list-agents:
    @echo "┌─────────────────────────────────────────────┐"
    @echo "│  Chaossynergy Agent Containers              │"
    @echo "├─────────────────────────────────────────────┤"
    @distrobox list 2>/dev/null | grep -E "^(hermes|opencode|pi|claude|inference)" || echo "│  No Chaossynergy agents found                  │"
    @echo "└─────────────────────────────────────────────┘"
    @echo ""
    @echo "Install missing agents: ujust setup-<name>"
    @echo "Remove an agent:        ujust remove-agent"

remove-agent:
    @read -p "Agent to remove (opencode/pi/claude): " name; \
    distrobox rm "$$name" 2>/dev/null && echo "✓ Removed $$name" || echo "✗ Agent '$$name' not found"

# ── Inference server ────────────────────────────────────────
# Dedicated distrobox with GPU access. One engine at a time.
# Pick llama.cpp or vLLM. Switching stops the other.

setup-inference-llama:
    @test -n "$(distrobox list 2>/dev/null | grep inference)" || { \
      echo "━━━ Creating inference distrobox ━━━"; \
      distrobox create --name inference \
        --image quay.io/fedora/fedora:latest \
        --additional-flags "--device nvidia.com/gpu=all -p 8080:8080" || exit 1; \
    }
    @echo "━━━ Installing llama CLI ━━━"
    distrobox enter inference -- bash -c "
      curl -LsSf https://llama.app/install.sh | sh
    " || exit 1
    @echo ""
    @echo "━━━ Configuring llama.cpp ━━━"
    # Stop and disable vLLM if running
    systemctl --user stop chaossynergy-vllm 2>/dev/null || true
    systemctl --user disable chaossynergy-vllm 2>/dev/null || true
    mkdir -p ~/.config/systemd/user/
    @cat > ~/.config/systemd/user/chaossynergy-inference.service << 'SERVICE'
[Unit]
Description=Chaossynergy Local Inference (llama.cpp)
After=network.target

[Service]
Type=simple
Environment=HOME=/root
ExecStart=/usr/bin/distrobox enter inference -- bash -c 'export PATH=$HOME/.local/bin:$PATH && exec llama serve -hf bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q4_K_M --host 0.0.0.0 --port 8080 -ngl 99 -c 32768'
Restart=on-failure

[Install]
WantedBy=default.target
SERVICE
    systemctl --user daemon-reload
    systemctl --user enable --now chaossynergy-inference.service 2>/dev/null || true
    @echo ""
    @echo "✓ llama.cpp running at http://127.0.0.1:8080/v1"
    @echo "  (auto-downloads GGUF on first request)"
    @echo ""
    @echo "━━━ Configuring Hermes ━━━"
    distrobox enter agent -- hermes config set providers.custom.local-llama.base_url "http://127.0.0.1:8080/v1" 2>/dev/null || true
    distrobox enter agent -- hermes config set providers.custom.local-llama.models '["bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q4_K_M", "bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q8_0"]' 2>/dev/null || true
    @echo "  hermes model set custom:local-llama/bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q4_K_M"
    @echo ""
    @echo "  Quant switch: ujust inference-model"
    @echo "  Switch engine: ujust setup-inference-vllm"

setup-inference-vllm:
    @test -n "$(distrobox list 2>/dev/null | grep inference)" || { \
      echo "━━━ Creating inference distrobox ━━━"; \
      distrobox create --name inference \
        --image quay.io/fedora/fedora:latest \
        --additional-flags "--device nvidia.com/gpu=all -p 8000:8000" || exit 1; \
    }
    @echo "━━━ Installing Python + vLLM ━━━"
    distrobox enter inference -- bash -c "
      dnf install -y python3-pip python3 && pip install --upgrade pip && pip install vllm
    " || exit 1
    @echo ""
    @echo "━━━ Configuring vLLM ━━━"
    # Stop and disable llama if running
    systemctl --user stop chaossynergy-inference 2>/dev/null || true
    systemctl --user disable chaossynergy-inference 2>/dev/null || true
    mkdir -p ~/.config/systemd/user/
    @cat > ~/.config/systemd/user/chaossynergy-vllm.service << 'SERVICE'
[Unit]
Description=Chaossynergy Local Inference (vLLM)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/distrobox enter inference -- vllm serve "bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF" --port 8000
Restart=on-failure

[Install]
WantedBy=default.target
SERVICE
    systemctl --user daemon-reload
    systemctl --user enable --now chaossynergy-vllm.service 2>/dev/null || true
    @echo ""
    @echo "✓ vLLM running at http://127.0.0.1:8000/v1"
    @echo ""
    @echo "━━━ Configuring Hermes ━━━"
    distrobox enter agent -- hermes config set providers.custom.local-vllm.base_url "http://127.0.0.1:8000/v1" 2>/dev/null || true
    distrobox enter agent -- hermes config set providers.custom.local-vllm.models '["bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF"]' 2>/dev/null || true
    @echo "  hermes model set custom:local-vllm/bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF"
    @echo ""
    @echo "  Switch engine: ujust setup-inference-llama"

inference-logs:
    journalctl --user -fu chaossynergy-inference 2>/dev/null || journalctl --user -fu chaossynergy-vllm

inference-stop:
    systemctl --user stop chaossynergy-inference 2>/dev/null || systemctl --user stop chaossynergy-vllm 2>/dev/null
    @echo "✓ Inference stopped"

inference-restart:
    systemctl --user restart chaossynergy-inference 2>/dev/null || systemctl --user restart chaossynergy-vllm 2>/dev/null
    @echo "✓ Inference restarted"

inference-status:
    @echo "┌─ Engines ──────────────────────────────────────┐"
    @systemctl --user is-active chaossynergy-inference 2>/dev/null && echo "│  Active: llama.cpp" || true
    @systemctl --user is-active chaossynergy-vllm 2>/dev/null && echo "│  Active: vLLM" || true
    @systemctl --user is-active chaossynergy-inference 2>/dev/null || systemctl --user is-active chaossynergy-vllm 2>/dev/null || echo "│  No inference engine running"
    @echo "└────────────────────────────────────────────────┘"
    distrobox enter inference -- nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader 2>/dev/null || true

inference-model:
    @read -p "Quant (Q4_K_M or Q8_0, default Q4_K_M): " quant; \
    quant="$${quant:-Q4_K_M}"; \
    systemctl --user stop chaossynergy-inference 2>/dev/null; \
    sed -i "s|-hf [^ ]*|-hf bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:$$quant|" ~/.config/systemd/user/chaossynergy-inference.service 2>/dev/null; \
    systemctl --user daemon-reload 2>/dev/null; \
    systemctl --user start chaossynergy-inference 2>/dev/null; \
    echo "✓ Switched to bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:$$quant"
# Repository layout (public vs private)

## Recommended structure

| Repo | Visibility | What lives here |
|------|------------|-----------------|
| **AI_TV_ORCHESTRATION** | **Public** | Docs, `.env.example`, stack profile example, plugin manifests, tunnel scripts |
| **FluxRT** (your fork) | **Private** | FLUX code, Gradio stream demo, ffmpeg fanout/mix, `5090-runpod` patches |
| **ai-tv-stack-scripts** | **Private** | RunPod bootstrap, `start_stack.sh`, tmux layout, weight download |

**Why this works:** public repo is the safe front door; private repos hold your fork and ops scripts. Fresh pods: clone orchestration → `.env` → `bin/clone-vendors.sh` → `full_setup.sh`.

## Making vendor repos private

GitHub → repo Settings → Danger Zone → Change visibility → Private. PAT needs `repo` scope.

## Clone order

```bash
git clone https://github.com/gschian0/AI_TV_ORCHESTRATION.git /workspace/AI_TV_ORCHESTRATION
cp /workspace/AI_TV_ORCHESTRATION/.env.example /workspace/AI_TV_ORCHESTRATION/.env
nano /workspace/AI_TV_ORCHESTRATION/.env
bash /workspace/AI_TV_ORCHESTRATION/bin/clone-vendors.sh
```

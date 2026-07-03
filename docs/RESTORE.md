# Restore AI TV Stack on a New RunPod

Use this after stopping a pod **without** the network volume, or to clone the stack on a fresh GPU.

## What you need backed up

| Item | Location | In git? |
|------|----------|---------|
| **Secrets** | `AI_TV_ORCHESTRATION/.env` | No — copy from `.env.example`, fill keys |
| Stack profile | `/workspace/.stack-profile.env` | Example: `stack-profile.env.example` |
| Model weights | `/workspace/FluxRT/weights/` | No — re-download with `download_weights.sh` |

**Secrets live in the orchestration repo folder**, not `/root/.env`. See [ENV.md](ENV.md).

If you **keep the RunPod network volume**, `/workspace` (including `AI_TV_ORCHESTRATION/.env` if you put it there) survives pod stops.

## 1. New pod with RTX 5090

- Template: Ubuntu + CUDA, **network volume** mounted at `/workspace`
- GPU: RTX 5090 (32GB VRAM recommended)

## 2. Clone repos (public first, then private)

```bash
cd /workspace
git clone https://github.com/gschian0/AI_TV_ORCHESTRATION.git

cp AI_TV_ORCHESTRATION/.env.example AI_TV_ORCHESTRATION/.env
nano AI_TV_ORCHESTRATION/.env   # GITHUB_PAT + HF + NVIDIA + Twitch + ngrok

bash AI_TV_ORCHESTRATION/bin/clone-vendors.sh
cp AI_TV_ORCHESTRATION/stack-profile.env.example /workspace/.stack-profile.env
```

Vendor repos (**FluxRT**, **ai-tv-stack-scripts**) are **private** — see [REPOS.md](REPOS.md).

## 4. Bootstrap

```bash
bash /workspace/full_setup.sh          # venv, deps, weights (if missing)
bash /workspace/start_stack.sh         # tmux: gradio, musicgen, quotes, mix, fanout
bash /workspace/check_stack.sh
```

Gradio UI: `http://127.0.0.1:7862` (or RunPod proxy port 7862).

## 5. Phone / HTTPS tunnel

```bash
bash /workspace/scripts/start_ngrok_gradio.sh
# Opens Gradio at NGROK_ENDPOINT_URL from AI_TV_ORCHESTRATION/.env
```

Webcam in Gradio requires HTTPS (ngrok or RunPod proxy).

## Stack topology

```
IPTV → Gradio (7862) → UDP 5000
MusicGen → UDP 5002
Quote TTS → UDP 5004
Mix bus (sidechain duck) → UDP 5006
Fanout → Twitch RTMP + HLS :8090
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Twitch video frozen | Ensure `BROADCAST_FPS=8` matches fanout `FPS=8` (default in `5090-runpod`) |
| No Twitch | Check `TWITCH_STREAM_KEY` in `AI_TV_ORCHESTRATION/.env` |
| Webcam blocked | Use HTTPS (ngrok), not raw `http://IP:7862` |
| GPU OOM | Set `MUSICGEN_DELAY=180` in `.stack-profile.env` |

## Pod reference (last known good)

- Branch: `5090-runpod` on FluxRT + ai-tv-stack-scripts
- Profile: `ENABLE_BRIDGE=0`, `MUSICGEN_DELAY=180`, `GRADIO_PORT=7862`

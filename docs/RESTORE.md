# Restore AI TV Stack on a New RunPod

Use this after stopping a pod **without** the network volume, or to clone the stack on a fresh GPU.

## What you need backed up (not in git)

| Item | Location | Notes |
|------|----------|-------|
| Secrets | `/root/.env` | HF, Twitch, NVIDIA, ngrok — copy to password manager |
| Stack profile | `/workspace/.stack-profile.env` | Example in `stack-profile.env.example` |
| Model weights | `/workspace/FluxRT/weights/` | ~30GB; re-download with `download_weights.sh` if missing |

If you **keep the RunPod network volume** attached, `/workspace` (FluxRT, models, scripts) survives — only restore `/root/.env`.

## 1. New pod with RTX 5090

- Template: Ubuntu + CUDA, **network volume** mounted at `/workspace`
- GPU: RTX 5090 (32GB VRAM recommended)

## 2. Clone repos

```bash
cd /workspace

git clone -b 5090-runpod https://github.com/gschian0/FluxRT.git FluxRT
git clone -b 5090-runpod https://github.com/gschian0/ai-tv-stack-scripts.git ai-tv-stack-scripts
git clone https://github.com/gschian0/AI_TV_ORCHESTRATION.git AI_TV_ORCHESTRATION

# Symlink workspace scripts (or copy from ai-tv-stack-scripts)
ln -sf /workspace/ai-tv-stack-scripts/*.sh /workspace/
mkdir -p /workspace/scripts
cp /workspace/AI_TV_ORCHESTRATION/scripts/*.sh /workspace/scripts/
chmod +x /workspace/*.sh /workspace/scripts/*.sh
```

## 3. Secrets + profile

```bash
cp /workspace/AI_TV_ORCHESTRATION/.env.example /root/.env
nano /root/.env   # paste your saved keys

cp /workspace/AI_TV_ORCHESTRATION/stack-profile.env.example /workspace/.stack-profile.env
```

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
# Opens Gradio at NGROK_ENDPOINT_URL from /root/.env
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
| No Twitch | Check `TWITCH_STREAM_KEY` in `/root/.env` |
| Webcam blocked | Use HTTPS (ngrok), not raw `http://IP:7862` |
| GPU OOM | Set `MUSICGEN_DELAY=180` in `.stack-profile.env` |

## Pod reference (last known good)

- Branch: `5090-runpod` on FluxRT + ai-tv-stack-scripts
- Profile: `ENABLE_BRIDGE=0`, `MUSICGEN_DELAY=180`, `GRADIO_PORT=7862`

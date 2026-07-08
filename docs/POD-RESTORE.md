# Pod Restore Runbook — AI TV Stack

Use this guide to bring up the FluxRT AI TV broadcast stack on any fresh RunPod, L40, or 5090 server.

## Repos and branches

| Repo | URL | Branches |
|------|-----|----------|
| AI_TV_ORCHESTRATION | https://github.com/gschian0/AI_TV_ORCHESTRATION | `mtx` (docs/secrets), `main` |
| FluxRT | https://github.com/gschian0/FluxRT | `5090-runpod` (9hr baseline), `mtx` (latest), `backup/20260702-233132-FluxRT` |
| ai-tv-stack-scripts | https://github.com/gschian0/ai-tv-stack-scripts | `5090-runpod`, `mtx`, `backup/20260702-233132-ai-tv-scripts` |

### Recommended profiles

| Profile file | Use when |
|--------------|----------|
| `stack-profile.simple.env.example` | **Default** — simple RTMP fanout + flat mix |
| `stack-profile.mtx.env.example` | MediaMTX hub fanout |
| `stack-profile.stable.env.example` | MediaMTX + watchdog + stall-aware ingest |

## Fresh pod setup

```bash
# 1. Clone orchestration (secrets + docs)
git clone -b mtx https://github.com/gschian0/AI_TV_ORCHESTRATION.git /workspace/AI_TV_ORCHESTRATION
cp /workspace/AI_TV_ORCHESTRATION/.env.example /workspace/AI_TV_ORCHESTRATION/.env
nano /workspace/AI_TV_ORCHESTRATION/.env   # fill keys — never commit

# 2. Clone vendors (private repos need GITHUB_PAT in .env)
bash /workspace/AI_TV_ORCHESTRATION/bin/clone-vendors.sh
# Or manually:
# git clone -b mtx https://github.com/gschian0/FluxRT.git /workspace/FluxRT
# git clone -b mtx https://github.com/gschian0/ai-tv-stack-scripts.git /workspace/ai-tv-stack-scripts

# 3. Install stack scripts
cp /workspace/ai-tv-stack-scripts/*.sh /workspace/
chmod +x /workspace/*.sh
cp /workspace/ai-tv-stack-scripts/stack-profile.simple.env.example /workspace/.stack-profile.env

# 4. System deps
apt-get update -qq && apt-get install -y -qq git git-lfs ffmpeg tmux curl python3 liquidsoap

# 5. Python env + models (see gotchas below)
bash /workspace/full_setup.sh
```

## Secrets checklist (`.env` — placeholders only)

| Variable | Required |
|----------|----------|
| `GITHUB_PAT` | Yes (private repo clone) |
| `HF_TOKEN` or `HF_API_KEY` | Yes (model download) |
| `TWITCH_STREAM_KEY` | Yes (broadcast) |
| `NVIDIA_API_KEY` | Yes (quote TTS) |
| `NGROK_*` | Optional (phone Gradio UI) |

Symlink: `ln -sf /workspace/AI_TV_ORCHESTRATION/.env /workspace/FluxRT/.env`

## Critical gotchas

### 1. Venv on local disk (RunPod network volume)

On RunPod, `/workspace` is often a slow network volume. Put the Python venv on local disk:

```bash
export PATH="$HOME/.local/bin:$PATH"
export UV_LINK_MODE=copy
export UV_CACHE_DIR=/root/.cache/uv
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install 3.12
uv venv /root/fluxrt-venv --python 3.12
ln -sf /root/fluxrt-venv /workspace/FluxRT/.venv
source /root/fluxrt-venv/bin/activate
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
uv pip install -e /workspace/FluxRT
```

Symptom if wrong: `Failed to hardlink files; falling back to full copy` then 30+ min silent stall.

### 2. HuggingFace model download

Do **not** rely on `git clone https://TOKEN@huggingface.co/...` for LFS. Use:

```bash
source /root/fluxrt-venv/bin/activate
hf auth login --token "$HF_TOKEN" --add-to-git-credential
cd /workspace/FluxRT
hf download TensorForger/RIFE-safetensors --local-dir RIFE-safetensors
hf download aydin99/FLUX.2-klein-4B-int8 --local-dir FLUX.2-klein-4B-int8
hf download black-forest-labs/FLUX.2-klein-4B --local-dir FLUX.2-klein-4B
```

### 3. Branch in setup_fluxrt.sh

Ensure `BRANCH="5090-runpod"` or `mtx` matches what you cloned. Default may say `runpod_tweak`.

### 4. Dual-GPU servers (e.g. dual L40)

Pin one GPU unless you wired multi-GPU yourself:

```bash
export CUDA_VISIBLE_DEVICES=0
```

### 5. LivePortrait

Keep off in `FluxRT/configs/stream_demo_config.json`: `"lip_transfer": { "enable": false }`

## Default prompts

**Video** (`5090-runpod` branch):

```
low-resolution video game screenshot in the style of 3DMVMKR, illustration in the style of SHNILLST
```

**Music** (default `STATION=reggae-king`):

```
cool groove, electronic chill downtempo, bassline and chords lead the track, fat reggae dub sub bassline, cool jazz chord progression, lush synth pads, airy ethereal melodies throughout, warm chord stabs, light understated drums, steady instrumental club lounge mix
```

**Radio:** `http://stream.zeno.fm/0a4yq1u0f0hvv`

## Boot commands

```bash
# Recommended one-command boot (waits for video + audio warm-up)
bash /workspace/go_live.sh

# Manual
bash /workspace/start_stack.sh
# wait ~2 min, then fanout via Gradio or go_live

# Stop everything
bash /workspace/stop_stack.sh

# Health check
bash /workspace/check_stack.sh
bash /workspace/start_stack_preflight.sh   # after warm-up
```

## Architecture (mixer vs distribution)

See `ai-tv-stack-scripts/ARCHITECTURE.md`. Summary:

- **Production/mixer:** Gradio (video) + Liquidsoap or ffmpeg (audio) + ffmpeg fanout (A+V mux)
- **Distribution:** Twitch, optional Owncast (HLS preview), optional OSP (heavy self-hosted UI)

Owncast and OSP accept **one RTMP stream** — they do not mix UDP sources.

## Optional Owncast preview

```bash
# In .stack-profile.env:
ENABLE_OWNCAST=1

bash /workspace/FluxRT/scripts/streaming/start_owncast_sidecar.sh
# Web UI: http://127.0.0.1:8080
# Fanout tees to rtmp://127.0.0.1:1935/live/owncast
```

## Rollback branches

```bash
# July 2 overnight 9-hour stable run
cd /workspace/FluxRT && git checkout backup/20260702-233132-FluxRT
cd /workspace/ai-tv-stack-scripts && git checkout backup/20260702-233132-ai-tv-scripts
cp stack-profile.simple.env.example /workspace/.stack-profile.env

# July 6 handoff snapshot
git checkout backup/20260706-l40-handoff
```

## RTMP targets

```bash
cp /workspace/FluxRT/scripts/streaming/rtmp_targets.env.example \
   /workspace/FluxRT/scripts/streaming/rtmp_targets.env
# Fill TWITCH_RTMP_URL=rtmp://live.twitch.tv/app/YOUR_KEY
```

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Black Twitch / `mean=0.00` | CUDA OOM — stop MusicGen, restart Gradio |
| Fanout dies ~25s / PPS errors | `/tmp/fluxrt-rtmp-fanout.log` — use `VIDEO_TRANSCODE_MODE=transcode`, `ENABLE_RECONNECT_BARS=0`, `WAIT_FOR_VIDEO_READY=0` in `go_live.sh` |
| Skip/stop on Twitch | Reconnect color bars — set `ENABLE_RECONNECT_BARS=0` |
| Choppy / fighting TTS | [TTS-AUDIO-UDP-FIX.md](TTS-AUDIO-UDP-FIX.md) — one writer per UDP port, fanout reads 5006 only |
| Models missing | `ls FluxRT/FLUX.2-klein-4B-int8 RIFE-safetensors` |
| Liquidsoap missing or root denied | `apt install liquidsoap` or set `USE_LIQUIDSOAP_MIX=0` (`.liq` includes `allow_root` if you enable it) |

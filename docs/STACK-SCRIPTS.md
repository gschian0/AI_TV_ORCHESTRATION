# Stack scripts — AI TV use case

[ai-tv-stack-scripts](https://github.com/gschian0/ai-tv-stack-scripts) (`5090-runpod` branch) is the **deployment and runtime layer** for the AI TV stack. It bootstraps a fresh RunPod pod, installs FluxRT, downloads models, and starts every service in tmux.

This repo ([AI_TV_ORCHESTRATION](../README.md)) owns secrets, profiles, tunnel scripts, and docs. Stack scripts own **how to run** the stack on `/workspace`.

## Workspace layout on RunPod

```
/workspace/
├── AI_TV_ORCHESTRATION/     ← secrets (.env), profiles, tunnel scripts, docs
├── FluxRT/                  ← visual + streaming code (see FLUXRT.md)
├── ai-tv-stack-scripts/     ← bootstrap / setup / start / stop scripts
├── .stack-profile.env       ← non-secret tuning (from stack-profile.env.example)
├── start_stack.sh           ← usually symlinked or copied from ai-tv-stack-scripts
├── full_setup.sh
├── check_stack.sh
└── scripts/                 ← ngrok tunnel scripts (from AI_TV_ORCHESTRATION)
```

## Script reference (AI TV)

| Script | When to use |
|--------|-------------|
| `bootstrap.sh` | Fresh pod one-liner: clone scripts + kick off setup |
| `full_setup.sh` | Clone FluxRT, install uv/venv/PyTorch, download all weights |
| `setup_fluxrt.sh` | FluxRT install only (called by full_setup) |
| `download_weights.sh` | FLUX, RIFE, int8 models (~30 GB) |
| `download_liveportrait.sh` | Optional lip-sync models (off in current profile) |
| `start_stack.sh` | **Main command** — kill old processes, start tmux stack |
| `stop_stack.sh` | Stop everything |
| `check_stack.sh` | Process list, GPU, HLS monitor sanity check |
| `scheduled_start.sh` | Delay stack start until a wall-clock time |

All scripts load secrets via `AI_TV_ORCHESTRATION/.env` first (see [ENV.md](ENV.md)).

## What `start_stack.sh` starts

tmux session **`fluxrt`** — 8 windows:

| Window | Name | AI TV role (current profile) |
|--------|------|------------------------------|
| 0 | gradio | FluxRT Gradio + inference → UDP 5000 |
| 1 | bridge | **Disabled** — Gradio publishes video directly |
| 2 | audio_src | MusicGen (delayed ~180s so video loads GPU first) |
| 3 | silence | **Disabled** — quote TTS owns UDP 5004 |
| 4 | mixbus | Sidechain duck: music + TTS → UDP 5006 |
| 5 | fanout | ffmpeg → Twitch RTMP + HLS monitor |
| 6 | monitor | HTTP server for HLS preview (port 8090) |
| 7 | prompts | **Disabled** by default (optional prompt rotator) |

Attach: `tmux attach -t fluxrt` · Detach: `Ctrl+B` then `D`

> The stack-scripts README on GitHub still shows an older diagram (bridge + silence). **This doc reflects the hybrid profile** pinned in `stack-profile.env.example`.

## Stack profile (non-secrets)

`/workspace/.stack-profile.env` — copied from `AI_TV_ORCHESTRATION/stack-profile.env.example`:

```bash
ENABLE_BRIDGE=0
MUSICGEN_DELAY=180
AUTO_START_STREAM=1
AUTO_START_DELAY=90
GRADIO_PORT=7862
MUSIC_MIX_VOLUME=0.55
TTS_MIX_VOLUME=0.95
BROADCAST_FPS=8
```

`start_stack.sh` sources this automatically when the file exists.

## Station presets

MusicGen radio source + base prompt:

```bash
STATION=reggae-king   bash /workspace/start_stack.sh   # default
STATION=chill-hop     bash /workspace/start_stack.sh
STATION=ambient       bash /workspace/start_stack.sh
STATION=roots-legacy  bash /workspace/start_stack.sh
```

Override manually:

```bash
RADIO_URL="http://your-radio" MUSIC_PROMPT="your style" bash /workspace/start_stack.sh
```

## Broadcast outputs

| Output | URL / port |
|--------|------------|
| Gradio UI (pod) | `http://127.0.0.1:7862` or RunPod proxy `:7862` |
| Gradio (phone) | ngrok `NGROK_ENDPOINT_URL` — see main README |
| HLS monitor | `http://127.0.0.1:8090/stream.m3u8` or RunPod proxy `:8090` |
| Twitch | RTMP via `TWITCH_STREAM_KEY` in `.env` |

Fanout reads **video** from UDP 5000 and **mixed audio** from UDP 5006 at **8 fps CFR**.

## Typical workflow

### New pod

```bash
git clone https://github.com/gschian0/AI_TV_ORCHESTRATION.git /workspace/AI_TV_ORCHESTRATION
git clone -b 5090-runpod https://github.com/gschian0/ai-tv-stack-scripts.git /workspace/ai-tv-stack-scripts
git clone -b 5090-runpod https://github.com/gschian0/FluxRT.git /workspace/FluxRT

cp /workspace/AI_TV_ORCHESTRATION/.env.example /workspace/AI_TV_ORCHESTRATION/.env
nano /workspace/AI_TV_ORCHESTRATION/.env

cp /workspace/AI_TV_ORCHESTRATION/stack-profile.env.example /workspace/.stack-profile.env
ln -sf /workspace/ai-tv-stack-scripts/*.sh /workspace/
mkdir -p /workspace/scripts
cp /workspace/AI_TV_ORCHESTRATION/scripts/*.sh /workspace/scripts/

bash /workspace/full_setup.sh
bash /workspace/start_stack.sh
bash /workspace/scripts/start_ngrok_gradio.sh
```

### Daily ops

```bash
bash /workspace/check_stack.sh
bash /workspace/stop_stack.sh
bash /workspace/start_stack.sh
```

### Scheduled show

```bash
bash /workspace/scheduled_start.sh 20:00 reggae-king
```

## Requirements (5090-runpod)

| | Minimum | Recommended |
|--|---------|-------------|
| GPU | RTX 4090 24 GB | RTX 5090 32 GB |
| CUDA | 12.4 | 12.8 |
| Disk | 100 GB | 200 GB+ (models on volume) |
| Python | 3.12 via uv | 3.12 |

## Relationship to this repo

| Concern | Owner |
|---------|--------|
| Clone, install, tmux, station presets | **ai-tv-stack-scripts** |
| FluxRT code, inference, ffmpeg streaming | **FluxRT** |
| `.env`, ngrok, restore docs, plugin manifests | **AI_TV_ORCHESTRATION** (here) |

When the stack-scripts README and this doc disagree, **trust this doc and `stack-profile.env.example`** for the current AI TV deployment.

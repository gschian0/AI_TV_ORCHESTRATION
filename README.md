# AI TV Orchestration

Master repo for the **AI TV stack** — an automated AI broadcast pipeline on RunPod (RTX 5090): real-time FLUX video, AI music, quote TTS, and Twitch output.

This repo is **public**. FluxRT and stack scripts stay **private** — see [docs/REPOS.md](docs/REPOS.md).

## Repositories

| Repo | Branch | Role | AI TV doc |
|------|--------|------|-----------|
| **AI_TV_ORCHESTRATION** (here) | Public | `main` | Docs, templates, ngrok | [REPOS.md](docs/REPOS.md) |
| FluxRT (your fork) | **Private** | `5090-runpod` | AI video + streaming | [FLUXRT.md](docs/FLUXRT.md) |
| ai-tv-stack-scripts | **Private** | `5090-runpod` | Bootstrap, tmux, start/stop | [STACK-SCRIPTS.md](docs/STACK-SCRIPTS.md) |

## Quick start (RunPod)

```bash
# 1. Public orchestration repo
cd /workspace
git clone https://github.com/gschian0/AI_TV_ORCHESTRATION.git

# 2. Secrets (GITHUB_PAT clones your private forks)
cp AI_TV_ORCHESTRATION/.env.example AI_TV_ORCHESTRATION/.env
nano AI_TV_ORCHESTRATION/.env

# 3. Private vendor repos → /workspace/FluxRT + ai-tv-stack-scripts
bash AI_TV_ORCHESTRATION/bin/clone-vendors.sh

# 4. Stack profile + install + run
cp AI_TV_ORCHESTRATION/stack-profile.env.example /workspace/.stack-profile.env
bash /workspace/full_setup.sh
bash /workspace/start_stack.sh
bash /workspace/scripts/start_ngrok_gradio.sh
```

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/REPOS.md](docs/REPOS.md) | Public vs private repo layout |
| [docs/ENV.md](docs/ENV.md) | `.env` in repo folder — HF, NVIDIA, Gemini, Twitch, ngrok |
| [docs/FLUXRT.md](docs/FLUXRT.md) | FluxRT fork for AI TV — UDP 5000, Gradio, quotes, fanout scripts |
| [docs/STACK-SCRIPTS.md](docs/STACK-SCRIPTS.md) | Bootstrap, tmux windows, station presets, daily commands |
| [docs/RESTORE.md](docs/RESTORE.md) | New pod / volume restore checklist |
| [docs/VIDEO_LOGIC.md](docs/VIDEO_LOGIC.md) | Video pipeline notes (bridge off, 8fps, mix bus) |

## Secrets (`.env`)

**Put secrets in `AI_TV_ORCHESTRATION/.env`** — same folder as `.env.example`. Never commit `.env`.

```bash
cp .env.example .env && nano .env
```

Includes: `GITHUB_PAT`, `HF_TOKEN`, `NVIDIA_API_KEY`, `TWITCH_STREAM_KEY`, ngrok API key + endpoint, optional `GEMINI_API_KEY`. Details: [ENV.md](docs/ENV.md).

## Current stack topology

Hybrid **5090-runpod** profile (`stack-profile.env.example`):

```
IPTV → Gradio (7862) → UDP 5000 ─┐
MusicGen → UDP 5002 ─┐           │
Quote TTS → UDP 5004 ┤→ mix → 5006 ─┤→ Twitch fanout → Twitch + HLS :8090
                     └─────────────┘
```

- Bridge **off** — Gradio encodes to UDP 5000 at **8 fps**
- Quote TTS on 5004 (no silence feed)
- Sidechain mix bus ducks music under quotes

## Plugin manifests

```
plugins/
  visual/fluxrt          active — AI video → UDP 5000
  audio/musicgen         active — AI music → UDP 5002
  audio/quote-tts        active — Magpie TTS → UDP 5004
  audio/audio-mix-bus    active — duck mix → UDP 5006
  output/twitch-fanout   active — RTMP + HLS
  spatial/*              planned
```

## Remote access (phone / webcam)

Gradio needs **HTTPS** for phone webcam. Use ngrok with your free-tier endpoint:

```bash
bash /workspace/scripts/start_ngrok_gradio.sh
# Uses NGROK_APIKEY + NGROK_ENDPOINT_URL from AI_TV_ORCHESTRATION/.env
```

| Method | HTTPS | Webcam |
|--------|-------|--------|
| RunPod proxy `:7862` | Yes | Yes |
| ngrok cloud endpoint | Yes | Yes |
| Raw `http://IP:7862` | No | Blocked |

See [ENV.md](docs/ENV.md) for ngrok API key vs authtoken.

## Commands

```bash
bash /workspace/start_stack.sh
bash /workspace/stop_stack.sh
bash /workspace/check_stack.sh
bash /workspace/scripts/start_ngrok_gradio.sh
tmux attach -t fluxrt
```

## License

Orchestration docs and scripts: use with the FluxRT fork and stack scripts under their respective licenses.

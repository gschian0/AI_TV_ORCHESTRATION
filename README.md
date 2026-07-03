# AI TV Orchestration

Master repo for the AI TV stack: visual plugins, audio plugins, spatial/3D plugins, and broadcast output — orchestrated from one place so you can spin the stack up on any GPU pod.

## Quick start (RunPod)

```bash
# 1. Secrets
cp AI_TV_ORCHESTRATION/.env.example /root/.env
nano /root/.env

# 2. Clone vendors (sibling dirs under /workspace)
git clone -b 5090-runpod https://github.com/gschian0/FluxRT /workspace/FluxRT
git clone -b 5090-runpod https://github.com/gschian0/ai-tv-stack-scripts /workspace/ai-tv-stack-scripts

# 3. Setup + start
bash /workspace/full_setup.sh
bash /workspace/start_stack.sh

# 4. Remote UI on your phone (HTTPS tunnel)
bash /workspace/scripts/start_ngrok_gradio.sh
```

## Plugin architecture

```
AI_TV_ORCHESTRATION/
  plugins/
    visual/     fluxrt (active) — FLUX diffusion video
    audio/      musicgen, quote-tts, audio-mix-bus (active)
    spatial/    depth, 360-cam, 3d-cam, human-tracking, ai-greenscreen (planned)
    output/     twitch-fanout (active)
```

Each plugin has a `plugin.yaml` manifest (ports, env, status). Swap flavors by changing the profile — e.g. replace `visual.fluxrt` with a future spatial pipeline without rewriting the whole stack.

| Plugin | Status | Role |
|--------|--------|------|
| `visual.fluxrt` | **active** | AI video filter → UDP 5000 |
| `audio.musicgen` | **active** | AI music → UDP 5002 |
| `audio.quote-tts` | **active** | Voice quotes → UDP 5004 |
| `audio.mix-bus` | **active** | Duck music under TTS → UDP 5006 |
| `output.twitch-fanout` | **active** | Twitch + HLS monitor |
| `spatial.*` | planned | Depth, 360°, 3D cams, tracking, AI greenscreen |

## Remote access — ngrok (phone / browser)

Gradio runs on the pod at **port 7862**. That port is only reachable on the pod’s private network unless you expose it.

### Why you need ngrok (or similar)

| Access method | URL example | Phone? | Webcam? |
|---------------|-------------|--------|---------|
| Raw `http://IP:7862` | `http://203.0.113.5:7862` | Often blocked / no HTTPS | **No** — browsers block camera on HTTP |
| RunPod proxy | `https://pod-id-7862.proxy.runpod.net` | Yes (HTTPS) | Yes |
| **ngrok** | `https://your-subdomain.ngrok-free.dev` | Yes (HTTPS) | Yes |

**You cannot use your phone’s webcam in Gradio unless the page is served over HTTPS.** Browsers treat `getUserMedia()` (webcam/mic) as a secure context only — `https://` or `localhost`. A plain `http://` address to a remote IP will load the UI but **webcam mode will fail** with a permissions / insecure context error.

ngrok gives you a public **HTTPS** URL that tunnels to `http://127.0.0.1:7862` on the pod, so you can:

- Open the Gradio UI on your phone from anywhere
- Change prompts, start/stop fanout, quote voice, etc.
- Use **webcam input** from your phone browser (HTTPS required)

### ngrok credentials (two different things)

Put these in `/root/.env`:

```bash
# REST API — manage endpoints from scripts (NOT the same as authtoken)
NGROK_APIKEY=your_ngrok_api_key

# Agent token — local ngrok process uses this to connect (auto-created if missing)
NGROK_AUTHTOKEN=...

# Your cloud endpoint from ngrok dashboard
NGROK_ENDPOINT_URL=https://your-subdomain.ngrok-free.dev
NGROK_ENDPOINT_ID=ep_your_endpoint_id
```

| Variable | What it is |
|----------|------------|
| `NGROK_APIKEY` | **API key** from [dashboard.ngrok.com/api-keys](https://dashboard.ngrok.com/api-keys). Used by our scripts to configure your cloud endpoint and create an agent authtoken. Safe to use in automation; still keep it secret. |
| `NGROK_AUTHTOKEN` | **Agent authtoken** — proves the `ngrok` binary on the pod to ngrok’s servers. Created automatically via API key, or copy from [get-started/your-authtoken](https://dashboard.ngrok.com/get-started/your-authtoken). |
| `NGROK_ENDPOINT_URL` | Stable public HTTPS URL you created in the ngrok dashboard. |
| `NGROK_ENDPOINT_ID` | Endpoint ID (`ep_…`) for traffic-policy updates via API. |

**Common mistake:** pasting the API key into `NGROK_AUTHTOKEN`. The agent will reject it (`ERR_NGROK_107`). Use `NGROK_APIKEY` for the API key; let `start_ngrok_gradio.sh` create the agent token.

### Start the tunnel

```bash
bash /workspace/scripts/start_ngrok_gradio.sh
# → Gradio (phone): https://your-subdomain.ngrok-free.dev
```

On ngrok free tier, the first visit may show an interstitial — tap **Visit Site**. Then Gradio loads over HTTPS.

Fallback (no ngrok account): `bash /workspace/scripts/start_cloudflared_gradio.sh` — gives a random `*.trycloudflare.com` URL (changes each restart).

## Stack topology (current hybrid profile)

```
IPTV → FluxRT (7862) → UDP 5000 ─┐
MusicGen → UDP 5002 ─┐           │
Quote TTS → UDP 5004 ┤→ mix → 5006 ─┤→ Twitch fanout → Twitch + HLS :8090
                     └─────────────┘
```

Profile: `/workspace/.stack-profile.env`  
Video notes: `/workspace/VIDEO_LOGIC.md`  
**Restore on new pod:** [docs/RESTORE.md](docs/RESTORE.md)

## Commands

```bash
bash /workspace/start_stack.sh      # start full stack (tmux)
bash /workspace/stop_stack.sh       # stop everything
bash /workspace/check_stack.sh      # status + logs
bash /workspace/scripts/start_ngrok_gradio.sh   # HTTPS tunnel for phone
```

## Vendors (not vendored into this repo)

| Repo | Branch | Path |
|------|--------|------|
| [FluxRT](https://github.com/gschian0/FluxRT) | `5090-runpod` | `/workspace/FluxRT` |
| [ai-tv-stack-scripts](https://github.com/gschian0/ai-tv-stack-scripts) | `5090-runpod` | `/workspace/ai-tv-stack-scripts` |

This orchestration repo owns **profiles, plugin manifests, tunnel scripts, and docs** — not the model code itself.

# FluxRT — AI TV use case

[FluxRT](https://github.com/gschian0/FluxRT) (`5090-runpod` branch) is the **visual engine** of the AI TV stack. It runs real-time FLUX.2-Klein diffusion over live IPTV, webcam, or local video and feeds the broadcast pipeline.

Upstream: fork of [tensorforger/FluxRT](https://github.com/tensorforger/FluxRT), retuned for **RunPod RTX 5090** and this broadcast workflow.

## What FluxRT does in AI TV

| Role | Detail |
|------|--------|
| **Input** | IPTV HLS stream, webcam, or local file via Gradio |
| **Processing** | FLUX.2-Klein int8 — stylizes each frame from your prompt |
| **Output** | Processed video → UDP **5000** (MPEG-TS) |
| **UI** | Gradio on port **7862** — prompts, stream control, fanout buttons |
| **Overlays** | Show name + scrolling philosopher quotes (burned into frame) |
| **Audio (in FluxRT repo)** | MusicGen, quote TTS, mix bus, RTMP fanout scripts |

FluxRT is **not** the orchestration layer. [Stack scripts](STACK-SCRIPTS.md) and this repo wire FluxRT into a full TV pipeline.

## How it fits the broadcast

```
IPTV / webcam
     ↓
run_gradio_stream_demo.py  (port 7862)
     ↓  FLUX inference + overlays
UDP 5000  ──────────────────────→  RTMP fanout  →  Twitch
                                      ↑
MusicGen (5002) + Quote TTS (5004) → mix (5006) ─┘
```

### Current hybrid profile (5090-runpod)

These differ from the generic FluxRT README and the older stack-scripts diagram:

| Setting | AI TV value | Why |
|---------|-------------|-----|
| `ENABLE_BRIDGE=0` | Gradio writes UDP 5000 directly | Fewer moving parts; no bridge lag |
| `BROADCAST_FPS=8` | Matches fanout CFR | Prevents Twitch freeze from frame drops |
| `lip_transfer.enable` | `false` in config | Saves VRAM; IPTV doesn’t need lip-sync |
| Resolution | 288×160 | Fits 5090 + Twitch bitrate |
| Quote TTS | UDP **5004** | Replaces silence feed on that port |
| Mix bus | Sidechain duck | Music ducks under quotes, no dropout fade |

See [VIDEO_LOGIC.md](VIDEO_LOGIC.md) for pipeline details.

## Key paths in `/workspace/FluxRT`

| Path | Purpose |
|------|---------|
| `scripts/run_gradio_stream_demo.py` | Main AI TV Gradio app (what `start_stack.sh` runs) |
| `configs/stream_demo_config.json` | Resolution, int8, lip_transfer, spatial cache |
| `scripts/streaming/start_rtmp_fanout.sh` | Twitch + HLS fanout from UDP 5000/5006 |
| `scripts/streaming/start_audio_mix_bus.sh` | Sidechain mix → UDP 5006 |
| `scripts/run_musicgen_radio_plus_musicGEN.py` | AI music from radio conditioning |
| `scripts/run_quote_tts_from_json.py` | NVIDIA Magpie TTS quotes → UDP 5004 |
| `scripts/generate_quote_data_diffusiongemma.py` | Refresh quote JSON via NVIDIA DiffusionGemma |
| `data/quotes/diffusiongemma_quotes.json` | Quote pool for ticker + TTS |
| `.env` | Symlink → `AI_TV_ORCHESTRATION/.env` (secrets) |

## Models (installed by stack scripts)

Downloaded by `download_weights.sh` / `full_setup.sh`:

| Model | Purpose |
|-------|---------|
| `FLUX.2-klein-4B` + int8 variant | Real-time diffusion (int8 required on 5090 TV profile) |
| `RIFE-safetensors` | Frame interpolation inside FluxRT |
| `LivePortrait` (optional) | Lip transfer — **off** in current AI TV profile |

Requires `HF_TOKEN` in `.env` for Hugging Face downloads.

## Secrets FluxRT reads

From `AI_TV_ORCHESTRATION/.env` (symlinked as `FluxRT/.env`):

| Key | Used by |
|-----|---------|
| `HF_TOKEN` / `HF_API_KEY` | Model download, MusicGen |
| `NVIDIA_API_KEY` | Magpie TTS (Riva), DiffusionGemma quote generation |
| `TWITCH_STREAM_KEY` | Written into `scripts/streaming/rtmp_targets.env` at stack start |

Full list: [ENV.md](ENV.md).

## Running FluxRT alone (debug)

Normally you use `bash /workspace/start_stack.sh`. For isolated tests:

```bash
cd /workspace/FluxRT
source .venv/bin/activate
python scripts/run_gradio_stream_demo.py --int8 \
  --server-name 0.0.0.0 --server-port 7862 \
  --config-path configs/stream_demo_config.json
```

Fanout and audio are separate scripts under `scripts/streaming/` — see [STACK-SCRIPTS.md](STACK-SCRIPTS.md).

## Fork changes vs upstream FluxRT

The upstream README covers VTubing, virtual webcam, OBS, and local GUI demos. For **AI TV**, ignore most of that — you use the **stream demo + streaming scripts** path.

`5090-runpod`-specific changes:

- PyTorch CUDA 12.8 (Blackwell / RTX 5090)
- int8 quantization default for 32 GB VRAM
- RunPod paths (`/workspace/FluxRT`)
- Expanded show-name list + quote ticker
- Streaming: UDP publishers, mix bus, RTMP fanout, auto-start IPTV
- `BROADCAST_FPS` env aligned with fanout

## Original FluxRT docs

For model architecture, spatial KV cache, benchmarks, and integration API, see the [FluxRT README](https://github.com/gschian0/FluxRT/blob/5090-runpod/README.md) on GitHub. That content is for developers extending the model — not required to operate the AI TV broadcast.

# FluxRT Video Pipeline (runpod_tweak — working config)

Logged 2026-07-03 from RunPod RTX 5090 pod `mmly7oyl23zw3a`.

## Architecture

```
IPTV HLS (afintl.com)
    │  ffmpeg relay
    ▼
UDP 5010  ──► Gradio / FluxRT inference (288×160, int8 FLUX.2-klein-4B)
                    │
                    │  processed BGR frames + TV overlay
                    ▼
              ffmpeg rawvideo → h264 MPEG-TS
                    │
                    ▼
              UDP 5000  ──► RTMP fanout ──► Twitch RTMP + HLS monitor :8090
```

Audio is separate (see 5090-runpod branch). Video fanout reads **only** UDP 5000 for video.

## Key settings that made video work

| Setting | Value | Why |
|---------|-------|-----|
| Branch | `runpod_tweak` | RunPod-tuned gradio + stream config |
| `ENABLE_BRIDGE` | `0` | Gradio writes UDP 5000 internally; bridge duplicates/corrupts |
| Resolution | 288×160 | Matches `stream_demo_config.json` |
| FPS | 8 | Inference + encoder target |
| `lip_transfer.enable` | `false` | LivePortrait crashes inference on 5090 |
| Models | int8 + fp16 klein-4B | ~17GB VRAM for video alone |
| `MUSICGEN_DELAY` | 120–180s | MusicGen competes for ~3GB GPU; delay avoids OOM |
| Video encoder | libx264 ultrafast, GOP=16 | Inside `_get_udp_writer()` in gradio |
| Fanout video input | `fifo_size=50000000&overrun_nonfatal=1` | Prevents UDP buffer overrun drops |

## Code paths (FluxRT)

### 1. Input relay → UDP 5010
`run_gradio_stream_demo.py` pulls IPTV via ffmpeg to `stream_relay_output_url`:
`udp://127.0.0.1:5010?pkt_size=1316&fifo_size=50000000&overrun_nonfatal=1`

### 2. Inference + broadcast gate
- Processed frames validated via `_is_processed_frame_valid()` (non-zero max pixel)
- `required_processed_streak` + buffer depth before `_set_broadcast_ready(True)`
- Fanout blocked until real AI frames (`_can_start_fanout_now()`)

### 3. Internal UDP 5000 writer (no bridge)
`_broadcast_sender_loop()` → `_write_to_udp()` → `_get_udp_writer()`:
```python
ffmpeg -f rawvideo -pix_fmt bgr24 -s 288x160 -r 8 -i - \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -g 16 -keyint_min 16 -x264-params repeat-headers=1:... \
  -f mpegts udp://127.0.0.1:5000?pkt_size=1316
```

### 4. Auto-start stream (RunPod)
Env vars read at gradio launch:
- `AUTO_START_STREAM=1` — starts IPTV after delay without UI click
- `AUTO_START_DELAY=90` — seconds to wait for model load
- `STREAM_URL` — optional override of default IPTV URL

### 5. Fanout (Twitch)
`start_rtmp_fanout.sh` reads UDP 5000 (video) + UDP 5006 (mixed audio from 5090 bus):
- Re-encodes to 288×160 @ 8fps CFR for Twitch ingest
- Tee: Twitch RTMP + local HLS at `/tmp/fluxrt-monitor/stream.m3u8`

## What breaks video

1. **Bridge enabled** — two writers on UDP 5000 → corrupt H264, decode errors
2. **lip_transfer enabled** — inference subprocess crash, all-zero frames
3. **MusicGen too early** — CUDA OOM, orphaned `multiprocessing.spawn` holds VRAM
4. **Fanout without fifo_size on video UDP** — circular buffer overrun, dropped frames
5. **Fanout restart mid-GOP** — `non-existing PPS` until next keyframe (GOP=16 ≈ 2s)

## Orphan cleanup before restart

```bash
pkill -9 -f 'multiprocessing.spawn import spawn_main'
pkill -9 -f run_gradio_stream_demo.py
bash /workspace/stop_stack.sh
bash /workspace/start_stack.sh
```

## Hybrid goal (this session)

**Applied:** FluxRT on `5090-runpod` branch with video-only patches:
- `lip_transfer.enable: false`
- `ENABLE_BRIDGE=0` in `.stack-profile.env`
- `AUTO_START_STREAM` in gradio
- Fanout `fifo_size` on video UDP input
- 5090 audio unchanged: silence on 5004, amix bus 0.85/1.55

Restart: `bash /workspace/stop_stack.sh && bash /workspace/start_stack.sh`

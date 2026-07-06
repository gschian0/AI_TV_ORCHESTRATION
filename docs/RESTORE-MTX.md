# Restore MediaMTX (mtx) Stack — Quick Reference

Saved: 2026-07-06. This is the known-good state after MediaMTX fanout migration, bars+audio Twitch test, quote TTS fixes, and claymation prompt.

## Git branches (`mtx`)

| Repo | Branch | Remote |
|------|--------|--------|
| FluxRT | `mtx` | https://github.com/gschian0/FluxRT/tree/mtx |
| ai-tv-stack-scripts | `mtx` | https://github.com/gschian0/ai-tv-stack-scripts/tree/mtx |
| AI_TV_ORCHESTRATION | `mtx` | https://github.com/gschian0/AI_TV_ORCHESTRATION/tree/mtx |

## Quick restore (on pod)

```bash
cd /workspace/FluxRT && git fetch origin && git checkout mtx && git pull origin mtx
cd /workspace/ai-tv-stack-scripts && git fetch origin && git checkout mtx && git pull origin mtx
cp /workspace/ai-tv-stack-scripts/*.sh /workspace/
cp /workspace/ai-tv-stack-scripts/stack-profile.mtx.env.example /workspace/.stack-profile.env

bash /workspace/stop_stack.sh
bash /workspace/start_stack.sh
```

Wait ~2 minutes for Gradio (7862), MusicGen, Quote TTS, and MediaMTX fanout (FANOUT_DELAY=120).

## Profile highlights (`.stack-profile.env`)

- `USE_MEDIAMTX_FANOUT=1` — ingest mixes 5002+5004 inline; no mix bus on 5006
- `AUTO_START_FANOUT=1`, `FANOUT_DELAY=120`
- `AUTO_START_QUOTE_VOICE=1`, `QUOTE_TTS_DELAY=120`
- `ENABLE_LOCAL_MONITOR=0`
- `BROADCAST_FPS=8`, claymation prompt in `stream_demo_config.json`

## Bars + audio test (bypass AI video)

Proves Twitch delivery when UDP 5000 video is flaky:

```bash
bash /workspace/FluxRT/scripts/streaming/fluxrt-bars-audio-test.sh
# stop:
bash /workspace/FluxRT/scripts/streaming/fluxrt-stop-bars-audio-test.sh
```

## Rollback to July 2 overnight backup

```bash
cd /workspace/FluxRT && git checkout backup/20260702-233132-FluxRT
cd /workspace/ai-tv-stack-scripts && git checkout backup/20260702-233132-ai-tv-scripts
# set USE_MEDIAMTX_FANOUT=0 in profile, use start_rtmp_fanout.sh
```

## Rollback mtx → RTMP fanout + mix bus

In `.stack-profile.env`: `USE_MEDIAMTX_FANOUT=0`, then `bash /workspace/stop_stack.sh && bash /workspace/start_stack.sh`

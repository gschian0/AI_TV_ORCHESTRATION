# MusicGen — AI TV sound (refining)

**Goal:** consistent **~1.5 minute instrumental diddies** — complete mini-tracks that feel like one groove, not 8-second fragments stitched together.

Status: **actively refining** (5090-runpod profile below).

## What a “diddy” means here

| Want | Avoid |
|------|--------|
| ~90s cohesive instrumental | New random vibe every 8s |
| Same key / groove / density | Parallel clips fighting each other |
| Intro → groove → outro songform | Drunk-walk parameter chaos |
| Background bed for AI TV | Vocals, drum solos, noise washes |

## Signal path

```
Internet radio (texture/tempo hint)
        ↓
run_musicgen_radio_plus_musicGEN.py
        ↓  UDP 5002 (AAC)
Mix bus (ducks under quote TTS) → UDP 5006 → Twitch
```

## Recommended profile (`stack-profile.env`)

These vars are read by `FluxRT/scripts/start_musicgen_radio_plus_musicGEN.sh`:

```bash
# --- MusicGen: 90s diddy target (refining) ---
MUSICGEN_DIDDY_TARGET_SECONDS=90
MUSICGEN_GEN_SECONDS=30
MUSICGEN_PARALLEL_CLIPS=1
MUSICGEN_SAMPLE_SECONDS=12
MUSICGEN_CONDITIONING_MODE=text
MUSICGEN_CONDITIONING_SECONDS=12
MUSICGEN_CROSSFADE_SECONDS=2.5
MUSICGEN_STREAM_DELAY_SECONDS=75
MUSICGEN_BOOTSTRAP_CLIPS=12
MUSICGEN_SEED=424242
MUSICGEN_DRUNK_WALK=0
MUSICGEN_TOP_K=100
MUSICGEN_TOP_P=0.80
MUSICGEN_TEMPERATURE=0.74
MUSICGEN_GUIDANCE_SCALE=3.2
MUSICGEN_PAUSE_SECONDS=0

# Station prompt (reggae-king default) — tuned for diddy form
MUSIC_PROMPT="complete 90 second instrumental diddy, electronic chill downtempo, fat reggae dub sub bassline, cool jazz chord progression, lush synth pads, airy melodies, warm chord stabs, light understated drums, steady club lounge groove, cohesive songform same key throughout, clear intro and steady develop, no vocals, no abrupt style change"
```

### Why these values

| Setting | Value | Rationale |
|---------|-------|-----------|
| `GEN_SECONDS` | **30** | Reliable on 5090 with video loaded; **3 crossfaded clips ≈ 90s diddy**. Try **90** when GPU headroom confirmed. |
| `PARALLEL_CLIPS` | **1** | Was 3 — parallel batches spawn different ideas at once and break diddy consistency. |
| `CROSSFADE_SECONDS` | **2.5** | Smoother joins between 30s chunks (was 1.2). |
| `TEMPERATURE` | **0.74** | Tighter than 0.78 — less wander. |
| `TOP_K` / `TOP_P` | 100 / 0.80 | Slightly narrower sampling. |
| `DRUNK_WALK` | **0** | Off — parameter random walk fights consistency. |
| `STREAM_DELAY_SECONDS` | **75** | ~2.5 clips buffered before air (stable under TTS ducking). |
| `BOOTSTRAP_CLIPS` | **12** | Short warm intro from cache, not 64 stale clips. |

## Roadmap (refinement)

1. **Now:** 30s chunks × 3, crossfade, parallel=1, tight prompt — sounds like one **~90s diddy**.
2. **Next:** `MUSICGEN_GEN_SECONDS=90` single generation if realtime factor & VRAM OK on pod.
3. **Later:** `facebook/musicgen-melody` + `CONDITIONING_MODE=hybrid` for true audio continuation between chunks.
4. **Later:** explicit diddy boundary in generator (reset prompt/seed every 90s with overlap).

## Tuning on the pod

After editing `/workspace/.stack-profile.env`:

```bash
bash /workspace/stop_stack.sh   # or kill musicgen only:
pkill -f run_musicgen_radio_plus_musicGEN.py
cd /workspace/FluxRT && source .venv/bin/activate
set -a && source /workspace/.stack-profile.env && set +a
bash scripts/start_musicgen_radio_plus_musicGEN.sh
tail -f /tmp/fluxrt-musicgen-radio.log
```

Look for `realtime_factor` in log — want **< 1.0** sustained so you never underrun.

## Station presets

Set in `start_stack.sh` via `STATION=` or override `MUSIC_PROMPT` in profile:

```bash
STATION=reggae-king bash /workspace/start_stack.sh
STATION=chill-hop   bash /workspace/start_stack.sh
```

All stations should use diddy-form language in the prompt (intro, steady groove, same key, no vocals).

## Mix bus levels

From stack profile (ducking under quotes):

- `MUSIC_MIX_VOLUME=0.55` — music bed under TTS
- `TTS_MIX_VOLUME=0.95` — quotes forward

## Related

- [STACK-SCRIPTS.md](STACK-SCRIPTS.md) — tmux `audio_src` window
- [FLUXRT.md](FLUXRT.md) — `scripts/start_musicgen_radio_plus_musicGEN.sh`

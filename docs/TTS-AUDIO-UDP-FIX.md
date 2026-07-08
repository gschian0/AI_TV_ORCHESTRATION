# Quote TTS + UDP Audio Bus Fix

Known-good audio layout for FluxRT AI TV. Apply on any RunPod when voice sounds choppy or fights music.

## Architecture

```
MusicGen  → UDP 5002 ─┐
Quote TTS → UDP 5004 ─┤→ mix bus → UDP 5006 → fanout → Twitch
```

- **5002** = MusicGen only
- **5004** = quote TTS only (no silence feed)
- **5006** = mixed audio only
- Fanout: `AUDIO_INPUT_URL=udp://127.0.0.1:5006`, `ENABLE_TTS_OVERLAY=0`

## Quick fix

```bash
pkill -f "anullsrc.*udp://127.0.0.1:5004" 2>/dev/null || true
cd /workspace/FluxRT
USE_LIQUIDSOAP_MIX=0 FORCE_RESTART=1 \
MUSIC_MIX_VOLUME=0.85 TTS_MIX_VOLUME=1.55 \
bash scripts/streaming/start_audio_mix_bus.sh
bash scripts/streaming/stop_rtmp_fanout.sh
ENABLE_TTS_OVERLAY=0 AUDIO_SOURCE_MODE=url \
AUDIO_INPUT_URL='udp://127.0.0.1:5006?pkt_size=1316&fifo_size=50000000&overrun_nonfatal=1' \
INPUT_URL='udp://127.0.0.1:5000?pkt_size=1316' \
bash scripts/streaming/start_rtmp_fanout.sh scripts/streaming/rtmp_targets.env
```

## Profile

```bash
MUSIC_MIX_VOLUME=0.85
TTS_MIX_VOLUME=1.55
ENABLE_TTS_OVERLAY=0
USE_MEDIAMTX_FANOUT=0
AUTO_START_QUOTE_VOICE=1
```

## Do not

- Publish silence + quote TTS both on UDP 5004
- Let fanout mix 5002+5004 when mix bus is enabled
- Use `dropout_transition=2` for flat quote-over-music mix

See also: [POD-RESTORE.md](POD-RESTORE.md)

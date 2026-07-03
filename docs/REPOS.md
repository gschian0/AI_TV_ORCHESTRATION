# Repository layout (public vs private)

## Current structure

| Repo | Visibility | What lives here |
|------|------------|-----------------|
| **AI_TV_ORCHESTRATION** | **Public** | Docs, `.env.example`, profiles, tunnel scripts, plugin manifests |
| **FluxRT** (your fork) | **Public** | FLUX inference, Gradio stream demo, streaming scripts (for now) |
| **ai-tv-stack-scripts** | **Private** | RunPod bootstrap, `start_stack.sh`, tmux layout, weight download |

Only **stack scripts** need to stay private. FluxRT can stay public — your `.env` (Twitch, ngrok, NVIDIA, etc.) never goes in git.

## Future: scripts out of FluxRT

Today some broadcast plumbing lives under `FluxRT/scripts/streaming/` (fanout, mix bus, MusicGen wrappers). Plan is to **move that ops code** into orchestration or stack-scripts over time, so FluxRT stays closer to “model + Gradio demo” only. No rush — current layout works on the pod.

## Clone order (new pod)

```bash
git clone https://github.com/gschian0/AI_TV_ORCHESTRATION.git /workspace/AI_TV_ORCHESTRATION

# FluxRT — public, no PAT
git clone -b 5090-runpod https://github.com/gschian0/FluxRT.git /workspace/FluxRT

# Stack scripts — private, needs GITHUB_PAT in .env
cp /workspace/AI_TV_ORCHESTRATION/.env.example /workspace/AI_TV_ORCHESTRATION/.env
nano /workspace/AI_TV_ORCHESTRATION/.env
bash /workspace/AI_TV_ORCHESTRATION/bin/clone-vendors.sh
```

Or use `clone-vendors.sh` alone — it clones FluxRT over HTTPS (public) and stack-scripts with your PAT.

## What must NOT go in any public repo

- Real `.env` or stream keys
- Hard-coded PATs in committed files

## Network volume

If you keep the RunPod volume, `/workspace` survives pod stops — re-clone only on a fresh volume.

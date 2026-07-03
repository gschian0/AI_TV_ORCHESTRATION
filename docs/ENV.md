# Environment files

The stack uses **two** env files with different jobs. Only one holds secrets.

## 1. Secrets — `AI_TV_ORCHESTRATION/.env`

**Put this file in the orchestration repo folder** (same directory as `.env.example`).

```bash
cd /workspace/AI_TV_ORCHESTRATION
cp .env.example .env
nano .env
```

| Variable | Required | Used for |
|----------|----------|----------|
| `GITHUB_PAT` | yes (setup) | Clone FluxRT and stack scripts |
| `HF_TOKEN` / `HF_API_KEY` | yes | Hugging Face model downloads |
| `NVIDIA_API_KEY` | yes | Magpie TTS (Riva) + DiffusionGemma quotes |
| `TWITCH_STREAM_KEY` | yes (broadcast) | Twitch RTMP fanout |
| `NGROK_APIKEY` | yes (phone UI) | ngrok REST API |
| `NGROK_ENDPOINT_URL` | yes (phone UI) | Your stable ngrok HTTPS URL |
| `NGROK_ENDPOINT_ID` | yes (phone UI) | Endpoint ID (`ep_…`) from ngrok dashboard |
| `NGROK_AUTHTOKEN` | optional | Agent token; auto-created if blank |
| `GEMINI_API_KEY` | optional | Future Gemini prompt/quote plugins |

`.env` is **gitignored**. Never commit it. Update `.env.example` when you add new keys (placeholders only).

### Load order

Scripts source `scripts/load-env.sh`, which checks in order:

1. `AI_TV_ORCHESTRATION/.env` ← **preferred**
2. `/workspace/AI_TV_ORCHESTRATION/.env`
3. `/root/.env` (legacy RunPod location)
4. `/workspace/.env` (legacy)

FluxRT gets a symlink: `FluxRT/.env` → your loaded secrets file.

### ngrok free account (one endpoint)

You only need **one** ngrok free setup — reuse on every pod:

1. [dashboard.ngrok.com/api-keys](https://dashboard.ngrok.com/api-keys) → copy API key → `NGROK_APIKEY`
2. [dashboard.ngrok.com/endpoints](https://dashboard.ngrok.com/endpoints) → create cloud endpoint → copy URL and `ep_…` ID
3. Run `bash /workspace/scripts/start_ngrok_gradio.sh` — it creates `NGROK_AUTHTOKEN` if missing and saves it back to `.env`

**Do not** paste the API key into `NGROK_AUTHTOKEN` — they are different credentials.

## 2. Stack profile — `.stack-profile.env`

Non-secret tuning (ports, delays, mix levels). Lives at `/workspace/.stack-profile.env`.

```bash
cp /workspace/AI_TV_ORCHESTRATION/stack-profile.env.example /workspace/.stack-profile.env
```

This file **can** live on the network volume; example is in the repo as `stack-profile.env.example`.

## Quick checklist (new pod)

```bash
git clone https://github.com/gschian0/AI_TV_ORCHESTRATION.git /workspace/AI_TV_ORCHESTRATION
cp /workspace/AI_TV_ORCHESTRATION/.env.example /workspace/AI_TV_ORCHESTRATION/.env
# paste keys from password manager
cp /workspace/AI_TV_ORCHESTRATION/stack-profile.env.example /workspace/.stack-profile.env
bash /workspace/full_setup.sh
bash /workspace/start_stack.sh
bash /workspace/scripts/start_ngrok_gradio.sh
```

## Migrating from `/root/.env`

If an older pod only has `/root/.env`:

```bash
cp /root/.env /workspace/AI_TV_ORCHESTRATION/.env
chmod 600 /workspace/AI_TV_ORCHESTRATION/.env
```

Scripts still read `/root/.env` as fallback, but the repo copy is the source of truth going forward.

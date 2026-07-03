#!/usr/bin/env bash
set -euo pipefail

# Expose Gradio on GRADIO_PORT to the internet (phone-friendly HTTPS).
# Tries ngrok first if NGROK_AUTHTOKEN is valid; falls back to cloudflared quick tunnel.

GRADIO_PORT="${GRADIO_PORT:-7862}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/load-env.sh" 2>/dev/null || true

if [[ -n "${NGROK_AUTHTOKEN:-}" ]] && command -v ngrok >/dev/null 2>&1; then
  if bash "$SCRIPT_DIR/start_ngrok_gradio.sh" 2>/tmp/ngrok-try.log | grep -q 'Gradio (phone):'; then
    exit 0
  fi
  echo "ngrok failed (check token at https://dashboard.ngrok.com/get-started/your-authtoken)"
  tail -3 /tmp/ngrok-try.log 2>/dev/null || true
  echo "Falling back to cloudflared..."
fi

exec bash "$SCRIPT_DIR/start_cloudflared_gradio.sh"

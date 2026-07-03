#!/usr/bin/env bash
set -euo pipefail

GRADIO_PORT="${GRADIO_PORT:-7862}"
LOG_FILE="${LOG_FILE:-/tmp/cloudflared-${GRADIO_PORT}.log}"
PID_FILE="${PID_FILE:-/tmp/cloudflared-${GRADIO_PORT}.pid}"
URL_FILE="${URL_FILE:-/tmp/cloudflared-${GRADIO_PORT}.url}"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "Installing cloudflared..."
  curl -sSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  if [[ -f "$URL_FILE" ]]; then
    echo "Gradio (phone): $(cat "$URL_FILE")"
    exit 0
  fi
fi

pkill -f "cloudflared tunnel --url http://127.0.0.1:${GRADIO_PORT}" 2>/dev/null || true
sleep 1
: > "$LOG_FILE"

nohup cloudflared tunnel --url "http://127.0.0.1:${GRADIO_PORT}" --no-autoupdate >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

PUBLIC_URL=""
for _ in $(seq 1 25); do
  PUBLIC_URL="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_FILE" | head -1 || true)"
  [[ -n "$PUBLIC_URL" ]] && break
  sleep 1
done

if [[ -n "$PUBLIC_URL" ]]; then
  echo "$PUBLIC_URL" > "$URL_FILE"
  echo "Gradio (phone): ${PUBLIC_URL}"
else
  echo "Tunnel starting — tail -f ${LOG_FILE}"
fi

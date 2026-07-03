#!/usr/bin/env bash
set -euo pipefail

GRADIO_PORT="${GRADIO_PORT:-7862}"
LOG_FILE="${LOG_FILE:-/tmp/ngrok-${GRADIO_PORT}.log}"
PID_FILE="${PID_FILE:-/tmp/ngrok-${GRADIO_PORT}.pid}"
API_URL="http://127.0.0.1:4040/api/tunnels"

if [[ -f /root/.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source /root/.env
  set +a
fi

if ! command -v ngrok >/dev/null 2>&1; then
  curl -sSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -o /tmp/ngrok.tgz
  tar -xzf /tmp/ngrok.tgz -C /usr/local/bin ngrok
  chmod +x /usr/local/bin/ngrok
fi

ensure_agent_authtoken() {
  if [[ -n "${NGROK_AUTHTOKEN:-}" ]]; then
    return 0
  fi
  if [[ -z "${NGROK_APIKEY:-}" ]]; then
    echo "Set NGROK_APIKEY or NGROK_AUTHTOKEN in /root/.env"
    echo "  API key:  https://dashboard.ngrok.com/api-keys"
    echo "  Authtoken: https://dashboard.ngrok.com/get-started/your-authtoken"
    exit 1
  fi
  echo "Creating agent authtoken from NGROK_APIKEY..."
  NGROK_AUTHTOKEN="$(curl -s -X POST "https://api.ngrok.com/credentials" \
    -H "Authorization: Bearer ${NGROK_APIKEY}" \
    -H "Ngrok-Version: 2" \
    -H "Content-Type: application/json" \
    -d '{"description":"ai-tv-gradio-agent"}' \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")"
  if [[ -z "$NGROK_AUTHTOKEN" ]]; then
    echo "Failed to create agent authtoken from API key."
    exit 1
  fi
  if grep -q '^NGROK_AUTHTOKEN=' /root/.env 2>/dev/null; then
    sed -i "s|^NGROK_AUTHTOKEN=.*|NGROK_AUTHTOKEN=${NGROK_AUTHTOKEN}|" /root/.env
  else
    echo "NGROK_AUTHTOKEN=${NGROK_AUTHTOKEN}" >> /root/.env
  fi
}

ensure_cloud_endpoint_policy() {
  [[ -n "${NGROK_APIKEY:-}" ]] || return 0
  [[ -n "${NGROK_ENDPOINT_ID:-}" ]] || return 0
  local policy='on_http_request:
  - actions:
      - type: forward-internal
        config:
          url: https://default.internal'
  curl -s -X PATCH "https://api.ngrok.com/endpoints/${NGROK_ENDPOINT_ID}" \
    -H "Authorization: Bearer ${NGROK_APIKEY}" \
    -H "Ngrok-Version: 2" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "import json; print(json.dumps({'traffic_policy': '''${policy}''', 'pooling_enabled': True}))")" \
    >/dev/null || true
}

ensure_agent_authtoken
ngrok config add-authtoken "$NGROK_AUTHTOKEN" >/dev/null 2>&1 || true
ensure_cloud_endpoint_policy

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  if [[ -n "${NGROK_ENDPOINT_URL:-}" ]]; then
    echo "Gradio (phone): ${NGROK_ENDPOINT_URL}"
  fi
  echo "ngrok already running (PID $(cat "$PID_FILE"))."
  exit 0
fi

pkill -f "ngrok http ${GRADIO_PORT}" 2>/dev/null || true
sleep 1
: > "$LOG_FILE"

# Cloud endpoints: agent joins internal pool; public URL forwards via traffic policy.
if [[ -n "${NGROK_ENDPOINT_URL:-}" ]]; then
  nohup ngrok http "$GRADIO_PORT" \
    --url https://default.internal \
    --pooling-enabled \
    --log=stdout >> "$LOG_FILE" 2>&1 &
else
  nohup ngrok http "$GRADIO_PORT" --log=stdout >> "$LOG_FILE" 2>&1 &
fi
echo $! > "$PID_FILE"
echo "Started ngrok -> http://127.0.0.1:${GRADIO_PORT}"

PUBLIC_URL="${NGROK_ENDPOINT_URL:-}"
if [[ -z "$PUBLIC_URL" ]]; then
  for _ in $(seq 1 20); do
    PUBLIC_URL="$(curl -s "$API_URL" 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for t in d.get('tunnels', []):
        if t.get('proto') == 'https':
            print(t['public_url'])
            break
except Exception:
    pass
" 2>/dev/null || true)"
    [[ -n "$PUBLIC_URL" ]] && break
    sleep 1
  done
fi

if [[ -n "$PUBLIC_URL" ]]; then
  echo "Gradio (phone): ${PUBLIC_URL}"
  echo "ngrok inspect:  http://127.0.0.1:4040"
else
  echo "Tunnel starting — tail -f ${LOG_FILE}"
fi

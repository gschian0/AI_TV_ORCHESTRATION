#!/usr/bin/env bash
set -euo pipefail

GRADIO_PORT="${GRADIO_PORT:-7862}"
PID_FILE="${PID_FILE:-/tmp/ngrok-${GRADIO_PORT}.pid}"

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    echo "Stopped ngrok PID $pid"
  fi
  rm -f "$PID_FILE"
fi

pkill -f "ngrok http ${GRADIO_PORT}" 2>/dev/null || true
echo "ngrok stopped."

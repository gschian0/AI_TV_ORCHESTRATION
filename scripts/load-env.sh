#!/usr/bin/env bash
# Source AI TV stack secrets from the orchestration repo (preferred) or legacy paths.
# Usage: source /workspace/AI_TV_ORCHESTRATION/scripts/load-env.sh

_ai_tv_orchestration_root() {
  if [[ -n "${AI_TV_ORCHESTRATION_ROOT:-}" && -f "${AI_TV_ORCHESTRATION_ROOT}/.env.example" ]]; then
    echo "${AI_TV_ORCHESTRATION_ROOT}"
    return 0
  fi
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [[ -f "${here}/.env.example" ]]; then
    echo "${here}"
    return 0
  fi
  if [[ -d /workspace/AI_TV_ORCHESTRATION && -f /workspace/AI_TV_ORCHESTRATION/.env.example ]]; then
    echo /workspace/AI_TV_ORCHESTRATION
    return 0
  fi
  return 1
}

load_ai_tv_env() {
  local orch_root env_file
  orch_root="$(_ai_tv_orchestration_root 2>/dev/null || true)"

  local candidates=()
  [[ -n "${orch_root}" ]] && candidates+=("${orch_root}/.env")
  candidates+=(
    /workspace/AI_TV_ORCHESTRATION/.env
    /root/.env
    /workspace/.env
  )

  for env_file in "${candidates[@]}"; do
    [[ -f "${env_file}" ]] || continue
    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
    export AI_TV_ENV_FILE="${env_file}"
    if [[ -z "${HF_TOKEN:-}" && -n "${HF_API_KEY:-}" ]]; then
      export HF_TOKEN="${HF_API_KEY}"
    fi
    if [[ -z "${HF_API_KEY:-}" && -n "${HF_TOKEN:-}" ]]; then
      export HF_API_KEY="${HF_TOKEN}"
    fi
    return 0
  done

  echo "WARNING: No .env found. Copy .env.example to AI_TV_ORCHESTRATION/.env and fill in keys." >&2
  echo "  cp AI_TV_ORCHESTRATION/.env.example AI_TV_ORCHESTRATION/.env" >&2
  return 1
}

load_ai_tv_env

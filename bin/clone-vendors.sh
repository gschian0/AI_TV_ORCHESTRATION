#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE="${WORKSPACE:-/workspace}"

source "${ORCH_ROOT}/scripts/load-env.sh"

: "${GITHUB_PAT:?Set GITHUB_PAT in ${ORCH_ROOT}/.env}"

FLUXRT_REPO="${FLUXRT_REPO:-gschian0/FluxRT}"
STACK_SCRIPTS_REPO="${STACK_SCRIPTS_REPO:-gschian0/ai-tv-stack-scripts}"
VENDOR_BRANCH="${VENDOR_BRANCH:-5090-runpod}"

clone_or_update() {
  local slug="$1" dest="$2" branch="$3"
  local url="https://${GITHUB_PAT}@github.com/${slug}.git"
  if [[ -d "${dest}/.git" ]]; then
    echo "=== Updating ${dest} (${branch}) ==="
    git -C "${dest}" fetch origin
    git -C "${dest}" checkout "${branch}"
    git -C "${dest}" pull origin "${branch}"
  else
    echo "=== Cloning ${slug} -> ${dest} (${branch}) ==="
    git clone -b "${branch}" "${url}" "${dest}"
  fi
}

mkdir -p "${WORKSPACE}"
clone_or_update "${FLUXRT_REPO}" "${WORKSPACE}/FluxRT" "${VENDOR_BRANCH}"
clone_or_update "${STACK_SCRIPTS_REPO}" "${WORKSPACE}/ai-tv-stack-scripts" "${VENDOR_BRANCH}"

ln -sf "${WORKSPACE}/ai-tv-stack-scripts"/*.sh "${WORKSPACE}/"
mkdir -p "${WORKSPACE}/scripts"
cp "${ORCH_ROOT}/scripts"/*.sh "${WORKSPACE}/scripts/"
chmod +x "${WORKSPACE}"/*.sh "${WORKSPACE}/scripts"/*.sh 2>/dev/null || true
[[ -f "${ORCH_ROOT}/.env" ]] && ln -sf "${ORCH_ROOT}/.env" "${WORKSPACE}/FluxRT/.env"

echo "Done. Next: bash ${WORKSPACE}/full_setup.sh"

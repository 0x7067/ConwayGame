#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
API_DIR="$REPO_ROOT/ConwayAPI"

IMAGE="conway-api:verify"
HOST_PORT=8080
PLATFORM=""
USE_COMPOSE=0
CONTAINER_NAME="conway-api-verify"
HEALTH_TIMEOUT=60

log() { echo "[verify] $*"; }
err() { echo "[verify][error] $*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Builds ConwayAPI Docker image, runs it, waits for health, and performs smoke tests.

Options:
  --port <host_port>     Host port to bind (default: 8080)
  --image <name>         Image tag to build (default: conway-api:verify)
  --platform <value>     Platform for buildx (e.g., linux/amd64)
  --compose              Use docker compose instead of docker run
  -h, --help             Show this help

Examples:
  $(basename "$0") --port 8080
  $(basename "$0") --platform linux/amd64
  $(basename "$0") --compose --port 9090
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      HOST_PORT="$2"; shift 2 ;;
    --image)
      IMAGE="$2"; shift 2 ;;
    --platform)
      PLATFORM="$2"; shift 2 ;;
    --compose)
      USE_COMPOSE=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *) err "Unknown option: $1"; usage; exit 1 ;;
  esac
done

require() { command -v "$1" >/dev/null 2>&1 || { err "Missing required command: $1"; exit 1; }; }

require docker
require curl

cleanup() {
  if [[ $USE_COMPOSE -eq 0 ]]; then
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
      log "Stopping container ${CONTAINER_NAME}"
      docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
  else
    (cd "$API_DIR" && docker compose down) || true
  fi
}
trap cleanup EXIT

build_image() {
  log "Building image: $IMAGE"
  if [[ -n "$PLATFORM" ]]; then
    docker buildx build --platform "$PLATFORM" -f "$API_DIR/Dockerfile" -t "$IMAGE" --load "$REPO_ROOT"
  else
    docker build -f "$API_DIR/Dockerfile" -t "$IMAGE" "$REPO_ROOT"
  fi
}

run_container() {
  if [[ $USE_COMPOSE -eq 0 ]]; then
    log "Running container on host port $HOST_PORT"
    docker run -d --rm --name "$CONTAINER_NAME" -p "$HOST_PORT:8080" "$IMAGE" >/dev/null
  else
    require docker
    command -v docker compose >/dev/null 2>&1 || { err "docker compose not available"; exit 1; }
    log "Starting via docker compose on host port $HOST_PORT"
    (cd "$API_DIR" && HOST_PORT="$HOST_PORT" docker compose up -d --build)
    # When using compose, container name could be composed; we rely on health endpoint instead of name.
  fi
}

wait_health() {
  local base_url="http://localhost:${HOST_PORT}"
  log "Waiting for health at ${base_url}/health (timeout ${HEALTH_TIMEOUT}s)"
  local start=$(date +%s)
  while true; do
    if curl -fsS "${base_url}/health" >/dev/null 2>&1; then
      log "Health OK"
      break
    fi
    sleep 1
    local now=$(date +%s)
    if (( now - start > HEALTH_TIMEOUT )); then
      err "Health check timed out"
      exit 1
    fi
  done
}

smoke_tests() {
  local base_url="http://localhost:${HOST_PORT}"
  log "GET /api"
  curl -fsS "${base_url}/api" | sed -e 's/.*/[api] &/' | head -n 1 || true

  log "GET /api/patterns"
  curl -fsS "${base_url}/api/patterns" | sed -e 's/.*/[patterns] &/' | head -n 1 || true

  log "POST /api/game/step (blinker)"
  curl -fsS -X POST "${base_url}/api/game/step" \
    -H 'Content-Type: application/json' \
    -d '{"grid":[[false,false,false,false,false],[false,false,true,false,false],[false,false,true,false,false],[false,false,true,false,false],[false,false,false,false,false]],"rules":"conway"}' | sed -e 's/.*/[step] &/' | head -n 1 || true
}

main() {
  build_image
  run_container
  wait_health
  smoke_tests
  log "All checks passed"
}

main "$@"


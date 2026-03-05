#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# PostgreSQL 18 + pgvector Clean Build Script
# -----------------------------------------------------------------------------

# Configuration variables
IMAGE_NAME="vibhorkumar123/pg18-vector"
IMAGE_TAG="v2.4"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

CONTAINER_NAME="pg18book"
BUILDPLATFORM="linux/amd64"

# Runtime settings
HOST_PORT="5432"
POSTGRES_USER="postgres"
POSTGRES_DB="postgres"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"  # override from env if desired

# Safety toggles
DO_SYSTEM_PRUNE="${DO_SYSTEM_PRUNE:-0}"            # set to 1 to prune
REMOVE_OLD_IMAGE="${REMOVE_OLD_IMAGE:-1}"          # set to 0 to keep old image
REMOVE_OLD_CONTAINER="${REMOVE_OLD_CONTAINER:-1}"  # set to 0 to keep old container

# Wait settings
WAIT_SECONDS="${WAIT_SECONDS:-60}"
SLEEP_INTERVAL="${SLEEP_INTERVAL:-2}"

echo "=== PostgreSQL 18 + pgvector Clean Build Script ==="
echo "Image:     ${FULL_IMAGE_NAME}"
echo "Container: ${CONTAINER_NAME}"
echo "Platform:  ${BUILDPLATFORM}"
echo "Port:      ${HOST_PORT}->5432"
echo

check_docker() {
  if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker and try again."
    exit 1
  fi
}

cleanup() {
  echo "Step 1: Cleaning up existing Docker artifacts..."

  if [[ "${REMOVE_OLD_CONTAINER}" == "1" ]]; then
    if docker ps -a --format "{{.Names}}" | grep -qx "${CONTAINER_NAME}"; then
      echo "  Removing existing container: ${CONTAINER_NAME}"
      docker rm -f "${CONTAINER_NAME}" >/dev/null
    fi
  else
    echo "  Skipping container removal (REMOVE_OLD_CONTAINER=0)"
  fi

  if [[ "${REMOVE_OLD_IMAGE}" == "1" ]]; then
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -qx "${FULL_IMAGE_NAME}"; then
      echo "  Removing existing image: ${FULL_IMAGE_NAME}"
      docker rmi "${FULL_IMAGE_NAME}" >/dev/null || true
    fi
  else
    echo "  Skipping image removal (REMOVE_OLD_IMAGE=0)"
  fi

  if [[ "${DO_SYSTEM_PRUNE}" == "1" ]]; then
    echo "  Pruning unused Docker resources (DO_SYSTEM_PRUNE=1)..."
    docker system prune -f
  else
    echo "  Skipping docker system prune (set DO_SYSTEM_PRUNE=1 to enable)"
  fi

  echo "  Cleanup completed!"
  echo
}

build_image() {
  echo "Step 2: Building fresh image from scratch..."
  echo "  (no-cache, pull latest base layers)"
  echo

  docker build \
    --platform "${BUILDPLATFORM}" \
    --build-arg "BUILDPLATFORM=${BUILDPLATFORM}" \
    --no-cache \
    --pull \
    --progress=plain \
    -t "${FULL_IMAGE_NAME}" \
    .

  echo
  echo "  Build completed successfully!"
  echo
}

start_container() {
  echo "Step 3: Starting container..."

  docker run -d \
    --platform "${BUILDPLATFORM}" \
    --name "${CONTAINER_NAME}" \
    -p "${HOST_PORT}:5432" \
    -e "POSTGRES_USER=${POSTGRES_USER}" \
    -e "POSTGRES_DB=${POSTGRES_DB}" \
    -e "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" \
    "${FULL_IMAGE_NAME}" >/dev/null

  echo "  Container started: ${CONTAINER_NAME}"
  echo
}

wait_for_ready() {
  echo "Step 4: Waiting for PostgreSQL to become ready (up to ${WAIT_SECONDS}s)..."

  local elapsed=0
  while true; do
    if docker exec "${CONTAINER_NAME}" /usr/pgsql-18/bin/pg_isready -h localhost -p 5432 -U "${POSTGRES_USER}" >/dev/null 2>&1; then
      echo "  ✓ PostgreSQL is ready"
      echo
      return 0
    fi

    if (( elapsed >= WAIT_SECONDS )); then
      echo "  ✗ Timed out waiting for PostgreSQL readiness"
      echo
      echo "  Container logs:"
      docker logs "${CONTAINER_NAME}" || true
      return 1
    fi

    sleep "${SLEEP_INTERVAL}"
    elapsed=$(( elapsed + SLEEP_INTERVAL ))
  done
}

run_tests() {
  echo "Step 5: Running tests..."

  echo "  Testing pgvector..."
  docker exec "${CONTAINER_NAME}" /usr/local/bin/test-pgvector.sh >/dev/null
  echo "  ✓ pgvector test passed"

  echo "  Testing all extensions (optional but recommended)..."
  docker exec "${CONTAINER_NAME}" /usr/local/bin/test-all-extensions.sh >/dev/null
  echo "  ✓ extension suite passed"

  echo
  echo "  All tests passed!"
  echo
}

print_summary() {
  echo "=== Build completed successfully! ==="
  echo
  echo "Your PostgreSQL 18 container is running."
  echo "Connection details:"
  echo "  Host:     localhost"
  echo "  Port:     ${HOST_PORT}"
  echo "  User:     ${POSTGRES_USER}"
  echo "  Database: ${POSTGRES_DB}"
  echo
  echo "Useful commands:"
  echo "  Connect to psql:  docker exec -it ${CONTAINER_NAME} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
  echo "  Check logs:       docker logs ${CONTAINER_NAME}"
  echo "  Stop container:   docker stop ${CONTAINER_NAME}"
  echo "  Start container:  docker start ${CONTAINER_NAME}"
  echo "  Remove container: docker rm -f ${CONTAINER_NAME}"
  echo
}

on_error() {
  echo
  echo "=== ERROR: build/test failed ==="
  echo "Container logs (if available):"
  docker logs "${CONTAINER_NAME}" 2>/dev/null || true
  echo
}
trap on_error ERR

main() {
  check_docker
  cleanup
  build_image
  start_container
  wait_for_ready
  run_tests
  print_summary
}

main "$@"

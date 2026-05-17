#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES=(catalog cart checkout orders ui)
IMAGE_TAG="${IMAGE_TAG:-latest}"

for service in "${SERVICES[@]}"; do
  echo "Building the-store-${service}:${IMAGE_TAG}"
  docker build -t "the-store-${service}:${IMAGE_TAG}" "${ROOT_DIR}/src/${service}"
done

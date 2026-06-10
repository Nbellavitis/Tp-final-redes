#!/usr/bin/env bash
# Construye la imagen local del generador de carga (Artillery) para la demo de escalado.
# Se construye en la arquitectura del host (amd64 o arm64), igual que las imagenes de The Store.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_TAG="${IMAGE_TAG:-latest}"

docker build \
  -t "the-store-loadgen:${IMAGE_TAG}" \
  -f "${ROOT_DIR}/src/load-generator/Dockerfile.k3s" \
  "${ROOT_DIR}/src/load-generator"

echo "Built the-store-loadgen:${IMAGE_TAG}"

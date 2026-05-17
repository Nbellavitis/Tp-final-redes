#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-latest}"
OUTPUT="${OUTPUT:-/tmp/the-store-images.tar}"

docker save \
  "the-store-catalog:${IMAGE_TAG}" \
  "the-store-cart:${IMAGE_TAG}" \
  "the-store-checkout:${IMAGE_TAG}" \
  "the-store-orders:${IMAGE_TAG}" \
  "the-store-ui:${IMAGE_TAG}" \
  -o "${OUTPUT}"

echo "Images exported to ${OUTPUT}"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
KEY_DIR="${HOME}/.ssh/tpe-redes"

mkdir -p "${KEY_DIR}"
chmod 700 "${HOME}/.ssh" "${KEY_DIR}"

for node in k3s-control k3s-worker-1 k3s-worker-2 k3s-worker-3; do
  source_key="${INFRA_DIR}/.vagrant/machines/${node}/virtualbox/private_key"
  target_key="${KEY_DIR}/${node}_private_key"

  if [[ ! -f "${source_key}" ]]; then
    echo "Missing Vagrant key for ${node}: ${source_key}" >&2
    exit 1
  fi

  cp "${source_key}" "${target_key}"
  chmod 600 "${target_key}"
  echo "Prepared ${target_key}"
done

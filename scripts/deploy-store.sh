#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${NAMESPACE:-the-store}"

kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"
kubectl apply -f "${ROOT_DIR}/dist/kubernetes.yaml" -n "${NAMESPACE}"
kubectl wait --namespace "${NAMESPACE}" --for=condition=available deployments --timeout=300s --all
kubectl wait --namespace "${NAMESPACE}" --for=condition=ready pods --timeout=300s --all

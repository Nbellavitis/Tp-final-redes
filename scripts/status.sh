#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${NAMESPACE:-the-store}"
DEFAULT_KUBECONFIG="${ROOT_DIR}/infra/kubeconfig"

if [[ -z "${KUBECONFIG:-}" && -f "${DEFAULT_KUBECONFIG}" ]]; then
  export KUBECONFIG="${DEFAULT_KUBECONFIG}"
fi

echo "== Nodes =="
kubectl get nodes -o wide

echo
echo "== System Pods =="
kubectl get pods -n kube-system -o wide

echo
echo "== Ingress =="
kubectl get ingress -A

echo
echo "== The Store =="
kubectl get pods -n "${NAMESPACE}" -o wide
kubectl get svc -n "${NAMESPACE}" -o wide
kubectl get ingress -n "${NAMESPACE}" -o wide

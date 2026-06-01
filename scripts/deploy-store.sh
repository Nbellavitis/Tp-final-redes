#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${NAMESPACE:-the-store}"
DEFAULT_KUBECONFIG="${ROOT_DIR}/infra/kubeconfig"
apply_output="$(mktemp -t the-store-apply.XXXXXX)"
trap 'rm -f "${apply_output}"' EXIT

if [[ -z "${KUBECONFIG:-}" && -f "${DEFAULT_KUBECONFIG}" ]]; then
  export KUBECONFIG="${DEFAULT_KUBECONFIG}"
fi

kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"
kubectl apply -f "${ROOT_DIR}/dist/kubernetes.yaml" -n "${NAMESPACE}" | tee "${apply_output}"

if grep -q '^configmap/checkout configured' "${apply_output}"; then
  kubectl rollout restart deployment/checkout -n "${NAMESPACE}"
fi

kubectl wait --namespace "${NAMESPACE}" --for=condition=available deployments --timeout=300s --all
kubectl wait --namespace "${NAMESPACE}" --for=condition=ready pods --timeout=300s --all
kubectl get pods -n "${NAMESPACE}" -o wide

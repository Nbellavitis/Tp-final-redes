#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-the-store}"

echo "== Nodes =="
kubectl get nodes -o wide

echo
echo "== Ingress =="
kubectl get ingress -A

echo
echo "== The Store =="
kubectl get all -n "${NAMESPACE}"

#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-the-store}"

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

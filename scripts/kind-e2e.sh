#!/usr/bin/env bash
# End-to-end spin-up on kind: build images, create cluster, install ingress, deploy via Helm.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-k8s-example}"
HELM_RELEASE="${HELM_RELEASE:-k8s-example}"
API_IMG="${API_IMG:-k8s-example-api:dev}"
WEB_IMG="${WEB_IMG:-k8s-example-web:dev}"
INGRESS_VERSION="v1.11.1"
KUBE_CONTEXT="kind-${CLUSTER_NAME}"

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing dependency: $1" >&2
    exit 1
  fi
}

require docker
require kind
require helm
require kubectl
require npm

echo "[1/8] Build API image (${API_IMG})"
(cd "$ROOT_DIR/api" && docker build -t "$API_IMG" .)

echo "[2/8] Build web bundle and image (${WEB_IMG})"
(cd "$ROOT_DIR/web" && npm install && npm run build && docker build -t "$WEB_IMG" .)

echo "[3/8] Create kind cluster (${CLUSTER_NAME}) if needed"
if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  kind create cluster --name "$CLUSTER_NAME"
fi

echo "[4/8] Install ingress-nginx (if missing)"
if ! kubectl --context "$KUBE_CONTEXT" get ns ingress-nginx >/dev/null 2>&1; then
  kubectl --context "$KUBE_CONTEXT" apply -f \
    "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_VERSION}/deploy/static/provider/kind/deploy.yaml"
fi
kubectl --context "$KUBE_CONTEXT" wait --namespace ingress-nginx \
  --for=condition=available deploy/ingress-nginx-controller --timeout=180s

echo "[5/8] Load images into kind"
kind load docker-image "$API_IMG" --name "$CLUSTER_NAME"
kind load docker-image "$WEB_IMG" --name "$CLUSTER_NAME"

echo "[6/8] Install/upgrade Helm release (${HELM_RELEASE})"
helm upgrade --install "$HELM_RELEASE" "$ROOT_DIR/deploy" \
  --set fullnameOverride="$HELM_RELEASE" \
  --set api.image="$API_IMG" \
  --set web.image="$WEB_IMG" \
  --set ingress.className=nginx \
  --set ingress.enabled=true \
  --kube-context "$KUBE_CONTEXT"

echo "[7/8] Wait for workloads to become ready"
kubectl --context "$KUBE_CONTEXT" wait deploy/"${HELM_RELEASE}-api" --for=condition=available --timeout=120s
kubectl --context "$KUBE_CONTEXT" wait deploy/"${HELM_RELEASE}-web" --for=condition=available --timeout=120s

echo "[8/8] Port-forward ingress controller to reach the app"
kubectl --context "$KUBE_CONTEXT" -n ingress-nginx port-forward svc/ingress-nginx-controller 8080:80

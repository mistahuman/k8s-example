#!/usr/bin/env bash
# End-to-end spin-up on kind: build images, create cluster, install ingress, deploy via Helm.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-k8s-example}"
HELM_RELEASE="${HELM_RELEASE:-k8s-example}"
API_IMG="${API_IMG:-k8s-example-api:dev}"
WEB_IMG="${WEB_IMG:-k8s-example-web:dev}"
CTRL_IMG="${CTRL_IMG:-k8s-example-controller:dev}"
INGRESS_VERSION="v1.11.1"
INGRESS_HOST="${INGRESS_HOST:-k8s-example.local}"
KIND_CONFIG="${KIND_CONFIG:-$ROOT_DIR/deploy/kind-config.yaml}"
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

echo "[1/9] Build API image (${API_IMG})"
(cd "$ROOT_DIR/api" && docker build -t "$API_IMG" .)

echo "[2/9] Build web bundle and image (${WEB_IMG})"
(cd "$ROOT_DIR/web" && npm install && npm run build && docker build -t "$WEB_IMG" .)

echo "[3/9] Build controller image (${CTRL_IMG})"
(cd "$ROOT_DIR/controller" && docker build -t "$CTRL_IMG" .)

echo "[4/9] Create kind cluster (${CLUSTER_NAME}) if needed"
if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
fi

echo "[5/9] Install ingress-nginx (if missing)"
# kubectl get pods -n ingress-nginx -w
# kubectl delete ns ingress-nginx
if ! kubectl --context "$KUBE_CONTEXT" get ns ingress-nginx >/dev/null 2>&1; then
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
#   kubectl --context "$KUBE_CONTEXT" apply -f \
    # "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_VERSION}/deploy/static/provider/kind/deploy.yaml"
fi

kubectl --context "$KUBE_CONTEXT" wait --namespace ingress-nginx \
  --for=condition=available deploy/ingress-nginx-controller --timeout=180s
kubectl --context "$KUBE_CONTEXT" wait --namespace ingress-nginx \
  --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=180s

echo "[6/9] Load images into kind"
kind load docker-image "$API_IMG" --name "$CLUSTER_NAME"
kind load docker-image "$WEB_IMG" --name "$CLUSTER_NAME"
kind load docker-image "$CTRL_IMG" --name "$CLUSTER_NAME"

echo "[7/9] Install/upgrade Helm release (${HELM_RELEASE})"
helm upgrade --install "$HELM_RELEASE" "$ROOT_DIR/deploy" \
  --set fullnameOverride="$HELM_RELEASE" \
  --set api.image="$API_IMG" \
  --set web.image="$WEB_IMG" \
  --set controller.image="$CTRL_IMG" \
  --set ingress.host="$INGRESS_HOST" \
  --set ingress.className=nginx \
  --set ingress.enabled=true \
  --kube-context "$KUBE_CONTEXT"

echo "[8/9] Wait for workloads to become ready"
kubectl --context "$KUBE_CONTEXT" wait deploy/"${HELM_RELEASE}-api" --for=condition=available --timeout=120s
kubectl --context "$KUBE_CONTEXT" wait deploy/"${HELM_RELEASE}-web" --for=condition=available --timeout=120s

echo "[9/9] Access the app"
echo "Add to /etc/hosts: 127.0.0.1 ${INGRESS_HOST}"
echo "Open: http://${INGRESS_HOST}:8080"

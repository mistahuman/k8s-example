#!/bin/sh
set -e

KIND_VERSION="v0.31.0"
KUBECTL_VERSION="stable"
BIN_DIR="/usr/local/bin"

ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# Check Docker
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed. Please install Docker first."
  exit 1
fi

# Install kubectl if missing
if ! command -v kubectl >/dev/null 2>&1; then
  echo "Installing kubectl..."

  if [ "$KUBECTL_VERSION" = "stable" ]; then
    KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  fi

  curl -fsSLo kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
  chmod +x kubectl
  sudo mv kubectl "$BIN_DIR/kubectl"
else
  echo "kubectl already installed"
fi

# Install kind if missing
if ! command -v kind >/dev/null 2>&1; then
  echo "Installing kind ${KIND_VERSION}..."

  curl -fsSLo kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
  chmod +x kind
  sudo mv kind "$BIN_DIR/kind"
else
  echo "kind already installed"
fi

# Version check
docker --version
kubectl version --client
kind version

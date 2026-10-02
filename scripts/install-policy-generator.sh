#!/usr/bin/env bash
# Install the Open Cluster Management Policy Generator Kustomize plugin.
# Prefers a workspace-local install so the repo is self-contained.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_VERSION="${POLICY_GENERATOR_VERSION:-v1.19.0}"
OS="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

PLUGIN_DIR="${ROOT}/.kustomize/plugin/policy.open-cluster-management.io/v1/policygenerator"
mkdir -p "${PLUGIN_DIR}"

ASSET="${OS}-${ARCH}-PolicyGenerator"
URL="https://github.com/open-cluster-management-io/policy-generator-plugin/releases/download/${PLUGIN_VERSION}/${ASSET}"

echo "Downloading ${URL}"
curl -fsSL -o "${PLUGIN_DIR}/PolicyGenerator" "${URL}"
chmod 0755 "${PLUGIN_DIR}/PolicyGenerator"

# Best-effort install to the default Kustomize plugin path (may fail in sandboxes)
DEFAULT_DIR="${HOME}/.config/kustomize/plugin/policy.open-cluster-management.io/v1/policygenerator"
mkdir -p "${DEFAULT_DIR}" 2>/dev/null || true
cp "${PLUGIN_DIR}/PolicyGenerator" "${DEFAULT_DIR}/PolicyGenerator" 2>/dev/null || true

echo "Installed: ${PLUGIN_DIR}/PolicyGenerator (${PLUGIN_VERSION})"
echo "Ready. Run: ./scripts/generate-policies.sh"

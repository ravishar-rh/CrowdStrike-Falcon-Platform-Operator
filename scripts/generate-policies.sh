#!/usr/bin/env bash
# Generate ACM Policy manifests from PolicyGenerator inputs (run on this laptop).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/policygenerator"
OUT="${ROOT}/policies"
LOCAL_PLUGIN="${ROOT}/.kustomize/plugin/policy.open-cluster-management.io/v1/policygenerator/PolicyGenerator"
HOME_PLUGIN="${HOME}/.config/kustomize/plugin/policy.open-cluster-management.io/v1/policygenerator/PolicyGenerator"

if [[ -x "${LOCAL_PLUGIN}" ]]; then
  export KUSTOMIZE_PLUGIN_HOME="${ROOT}/.kustomize/plugin"
elif [[ -x "${HOME_PLUGIN}" ]]; then
  :
else
  echo "Policy Generator plugin not found."
  echo "Install it with: ${ROOT}/scripts/install-policy-generator.sh"
  exit 1
fi

mkdir -p "${OUT}"
rm -f "${OUT}/falcon-operator-policies.yaml"

echo "Generating policies from ${SRC} ..."
(
  cd "${SRC}"
  kustomize build --enable-alpha-plugins .
) > "${OUT}/falcon-operator-policies.yaml"

cat > "${OUT}/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - falcon-operator-policies.yaml
EOF

echo "Wrote ${OUT}/falcon-operator-policies.yaml"
echo "Commit the policies/ directory and point OpenShift GitOps at it."

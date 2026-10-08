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
rm -f "${OUT}/falcon-operator-policies.yaml" \
      "${OUT}/policy-falcon-operator-install.yaml" \
      "${OUT}/falcon-operator-secrets-crs-policies.yaml"

build_one() {
  local generator_file="$1"
  local outfile="$2"
  local tmp
  tmp="$(mktemp -d)"
  cp "${SRC}/${generator_file}" "${tmp}/"
  cp -R "${SRC}/input" "${tmp}/input"
  cat > "${tmp}/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
generators:
  - ${generator_file}
labels:
  - pairs:
      app.kubernetes.io/part-of: crowdstrike-falcon
      app.kubernetes.io/managed-by: policy-generator
    includeSelectors: false
EOF
  kustomize build --enable-alpha-plugins "${tmp}" > "${outfile}"
  rm -rf "${tmp}"
}

echo "Generating operator-install policy (no credentials required) ..."
build_one policyGenerator-install.yaml "${OUT}/policy-falcon-operator-install.yaml"
cp "${OUT}/policy-falcon-operator-install.yaml" "${OUT}/falcon-operator-policies.yaml"

echo "Generating optional secrets+CRs policy (disabled until credentials exist) ..."
build_one policyGenerator-secrets-crs.yaml "${OUT}/falcon-operator-secrets-crs-policies.yaml"

cat > "${OUT}/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# App-of-apps: list files under your sources/policies kustomization resources:.
# Start with operator install only. Enable secrets/CRs after ExternalSecret is Ready.
resources:
  - policy-falcon-operator-install.yaml
  # - falcon-operator-secrets-crs-policies.yaml
EOF

echo
echo "Wrote:"
echo "  ${OUT}/policy-falcon-operator-install.yaml"
echo "  ${OUT}/falcon-operator-policies.yaml  (same content — install only)"
echo "  ${OUT}/falcon-operator-secrets-crs-policies.yaml  (optional)"
echo
echo "App-of-apps checklist:"
echo "  1. Copy policy-falcon-operator-install.yaml into sources/policies/"
echo "  2. Add it to that directory's kustomization.yaml resources: list"
echo "  3. Sync GitOps — you should see Policy + Placement + PlacementBinding (no PolicySet)"
echo "  4. Approve InstallPlan if installPlanApproval is Manual"
echo "  Operator installs without AWS/ExternalSecret credentials."

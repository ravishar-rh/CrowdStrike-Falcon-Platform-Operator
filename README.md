# CrowdStrike Falcon Platform Operator on ROSA HCP + ACM

GitOps-ready manifests to install **CrowdStrike Falcon Platform - Operator `v1.15.0`** from the Red Hat **`certified-1.0`** channel onto a **ROSA Hosted Control Plane (HCP)** hub that runs **Red Hat Advanced Cluster Management (ACM)**, and to propagate the same install to **imported managed clusters**.

Policies are produced on this laptop with the **ACM Policy Generator**, committed under `policies/`, and synced by **OpenShift GitOps (Argo CD)**.

---

## What this operator does

The Falcon Operator is a Red Hat–certified OLM operator that deploys CrowdStrike protection on OpenShift via custom resources:

| Custom resource | Purpose | Default namespace |
| --- | --- | --- |
| **FalconNodeSensor** | Privileged DaemonSet: Falcon Linux sensor on worker nodes (RHCOS). Runtime protection for the node OS and containers. | `falcon-system` |
| **FalconAdmission** | Kubernetes Admission Controller (KAC): validates workloads and provides cluster visibility. | `falcon-kac` |
| **FalconImageAnalyzer** | Image Assessment at Runtime (IAR): scans images used by workloads. | `falcon-image-analyzer` |
| **FalconContainer** | Sidecar injector for non-OpenShift Kubernetes. **Do not use on OpenShift.** | — |
| **FalconDeployment** | Optional umbrella CR that creates the above in one object. This repo uses individual CRs for clearer ACM dependencies. | — |

For OpenShift (including ROSA HCP), CrowdStrike recommends **FalconNodeSensor** for runtime protection — not FalconContainer.

**Operator version matrix (1.15.0):** Node sensor ≥ 7.40 · KAC ≥ 7.33 · IAR ≥ 1.0.26.

---

## Repository layout

```text
.
├── README.md
├── policygenerator/                 # Policy Generator inputs (edit these)
│   ├── kustomization.yaml
│   ├── policyGenerator.yaml
│   └── input/
│       ├── operator/                # Namespace, OperatorGroup, Subscription
│       ├── secrets/                 # Hub-templated Falcon API Secret
│       ├── falcon-crs/              # FalconNodeSensor / Admission / ImageAnalyzer
│       └── placement/               # ACM Placement (OpenShift vendor)
├── policies/                        # GENERATED — commit this for GitOps
│   ├── falcon-operator-policies.yaml
│   └── kustomization.yaml
├── gitops/
│   ├── external-secrets/            # ExternalSecret → falcon-api-credentials
│   ├── application-external-secrets.yaml
│   ├── openshift-gitops-rbac.yaml   # RBAC for Argo CD → ACM Policies
│   └── application.yaml             # Argo CD Application
├── terraform/aws-secretsmanager-falcon/  # Creates AWS SM secret (step 1)
├── scripts/
│   ├── install-policy-generator.sh
│   └── generate-policies.sh
└── examples/openshift-virtualization/
    ├── README.md
    ├── ansible-vm-sensor.yml
    ├── cloud-init-linux-sensor.yaml
    └── falconnodesensor-virt-overlay.yaml
```

---

## How deployment works

```text
 Laptop                         GitHub                      ROSA HCP (ACM hub)
 ┌─────────────────────┐       ┌──────────────┐            ┌─────────────────────────────┐
 │ PolicyGenerator     │       │ policies/    │  Argo CD   │ Policy / PolicySet          │
 │ + input manifests   │──────▶│ (generated)  │───────────▶│ Placement → managed clusters│
 │ generate-policies.sh│       │              │            │ enforce Subscription + CRs  │
 └─────────────────────┘       └──────────────┘            └──────────────┬──────────────┘
                                                                          │
                                                   ┌──────────────────────┼──────────────────────┐
                                                   ▼                      ▼                      ▼
                                              Hub cluster           Imported cluster A     Imported cluster B
                                              falcon-operator       falcon-operator        falcon-operator
                                              + sensors             + sensors              + sensors
```

1. You edit `policygenerator/input/*` and regenerate policies on this laptop.
2. You push `policies/` (and optionally the generator sources) to GitHub.
3. OpenShift GitOps applies Policies onto the ACM hub (`rhacm-policies` namespace).
4. ACM Placement selects OpenShift clusters (`vendor=OpenShift`), including the hub (if labeled) and imported clusters.
5. ConfigurationPolicies enforce Namespace / OperatorGroup / Subscription / Secret / Falcon CRs on each selected cluster.
6. OLM installs `falcon-operator.v1.15.0` from `certified-operators`; the CSV brings its own ClusterRoles/Bindings/ServiceAccounts.
7. Falcon CRs reconcile sensors using credentials from the hub-templated Secret.

---

## Prerequisites

### Clusters

- ROSA **HCP** cluster with **ACM** installed (hub).
- **OpenShift GitOps** on the hub.
- Managed clusters imported into ACM (optional but expected).
- Outbound HTTPS to CrowdStrike Falcon cloud (and registry) from worker nodes / operator pods.
- OperatorHub catalog `certified-operators` available (`openshift-marketplace`).

### Falcon API client

Create an API client in the Falcon console with at least:

| Scope | Needed for |
| --- | --- |
| **Falcon Images Download: Read** | Node / KAC images |
| **Sensor Download: Read** | Sensor packages |
| **Falcon Container Image: Read/Write** + **Falcon Container CLI: Write** | Image Analyzer (if enabled) |
| **Sensor Update Policies: Read** | Optional advanced auto-update |

### ROSA HCP note

On ROSA HCP the control plane is hosted by Red Hat — you only manage workers. Falcon Node Sensor on workers is fully supported. The Classic ROSA “don’t put workloads on control-plane/infra” constraint does not apply the same way on HCP.

---

## Quick start (laptop → Git → GitOps)

### 1. Install Policy Generator plugin

```bash
./scripts/install-policy-generator.sh
```

### 2. (Optional) Customize inputs

- Cloud region: set `falcon_api.cloud_region` in the CRs if not using `autodiscover` (`us-1`, `us-2`, `us-3`, `eu-1`, …).
- Placement: tighten `policygenerator/input/placement/placement-falcon-operator.yaml` (e.g. `environment=prod`).
- Subscription: switch `installPlanApproval` to `Automatic` if you do not want Manual InstallPlan approvals.

### 3. Generate ACM policies

```bash
./scripts/generate-policies.sh
```

Outputs:
- `policies/policy-falcon-operator-install.yaml` — **use this** in app-of-apps (operator only, no credentials)
- `policies/falcon-operator-secrets-crs-policies.yaml` — optional; policies are `disabled: true` until credentials exist

### App-of-apps with gate files (`clusters/<name>/*.yaml` → `sources/<app>/`)

This matches the common OpenShift GitOps pattern:

| Piece | Role |
| --- | --- |
| `clusters/<hub>/policies.yaml` | **Gate file** — creates an Argo CD Application for that cluster |
| `sources/policies/` | App content. Gate filename `policies.yaml` ⇒ path `sources/policies` |
| No `kustomization.yaml` required | Argo CD directory mode applies every `*.yaml` in that folder |

**What to drop**

1. Put **`policy-falcon-operator-install.yaml`** in `sources/policies/` (replace any older `falcon-operator-policies.yaml`).
2. Confirm a hub gate exists, e.g. `clusters/<your-hub>/policies.yaml` (even `{}` / minimal overrides is enough).
3. Commit + push the **app-of-apps repo** (not only this Falcon repo).
4. In Argo CD, open the Application named like `<hub>---platform---policies` and check **sync status / errors**.

You should see on the hub: `Policy/policy-falcon-operator-install`, `Placement/placement-falcon-operator`, `PlacementBinding` — **not** a PolicySet.

**If other files in `sources/policies` sync but Falcon does not**, the usual cause is the *old* multi-doc file: it had a `PolicySet` and `{{hub fromSecret ...}}` strings that break sync for that manifest (and can leave the whole app unhealthy). Use the install-only file (no hub templates, no PolicySet).

**Credentials are not required for operator install.** Sensors/CRs come later via `falcon-operator-secrets-crs-policies.yaml` after ExternalSecret exists.

### 4. Provide hub credentials via Terraform + External Secrets (no manual K8s Secret)

This hub uses **External Secrets Operator**. Do **not** `oc create secret` by hand.

1. **Create the AWS Secrets Manager secret with Terraform:**

```bash
cd terraform/aws-secretsmanager-falcon
export TF_VAR_falcon_client_id='YOUR_CLIENT_ID'
export TF_VAR_falcon_client_secret='YOUR_CLIENT_SECRET'
export TF_VAR_falcon_cid='YOUR_CID'
export TF_VAR_falcon_provisioning_token=''
terraform init && terraform apply
```

Default secret name: `crowdstrike/falcon-operator`. Details: [`terraform/aws-secretsmanager-falcon/README.md`](terraform/aws-secretsmanager-falcon/README.md).

2. Edit `gitops/external-secrets/externalsecret-falcon-api-credentials.yaml` and set `secretStoreRef` to your existing `ClusterSecretStore` / `SecretStore`, and `remoteRef.key` to the Terraform `secret_name` output (default `crowdstrike/falcon-operator`).

3. Sync via GitOps (pick one):
   - Apply `gitops/application-external-secrets.yaml` (Argo CD Application in this repo), **or**
   - Drop `gitops/external-secrets/externalsecret-falcon-api-credentials.yaml` into your existing hub GitOps path for `rhacm-policies`.

4. Confirm the Secret was materialized:

```bash
oc get externalsecret,secret -n rhacm-policies falcon-api-credentials
```

ACM hub templates then copy those values into each managed cluster’s `falcon-operator/falcon-secrets` Secret. Details: [`gitops/external-secrets/README.md`](gitops/external-secrets/README.md).

### 5. Grant OpenShift GitOps RBAC on the hub

```bash
oc apply -f gitops/policies-namespace.yaml
oc apply -f gitops/openshift-gitops-rbac.yaml
```

### 6. Push to GitHub and sync

1. Update `repoURL` in `gitops/application.yaml`.
2. Commit and push this repository.
3. Apply the Argo CD Application:

```bash
oc apply -f gitops/application.yaml
```

### 7. Approve InstallPlans (Manual approval)

Subscription uses `installPlanApproval: Manual` and `startingCSV: falcon-operator.v1.15.0`.

On each target cluster (or via a script over managed clusters):

```bash
oc get installplan -n falcon-operator
oc patch installplan <name> -n falcon-operator \
  --type merge -p '{"spec":{"approved":true}}'
```

After the CSV is Succeeded, Falcon CRs become Compliant and sensors roll out.

### 8. Verify

```bash
# Hub policy status
oc get policy,policyset,placement,placementbinding -n rhacm-policies

# On a managed cluster
oc get csv -n falcon-operator
oc get falconnodesensor,falconadmission,falconimageanalyzer -A
oc get ds -n falcon-system
oc get pods -n falcon-kac
oc get pods -n falcon-image-analyzer
```

---

## RBAC included

| Manifest | Why |
| --- | --- |
| `gitops/openshift-gitops-rbac.yaml` | Lets Argo CD create/update ACM `Policy`, `PolicySet`, `Placement`, `PlacementBinding`. |
| Falcon Operator CSV (OLM) | Operator’s own ClusterRoles, ClusterRoleBindings, ServiceAccounts, and SCCs — **do not recreate manually**. |
| Privileged namespace labels | PSA labels on Falcon namespaces so the privileged node sensor / KAC can schedule. |

No extra ClusterRole is required for the Falcon Operator beyond what OLM installs from the certified CSV.

---

## Generated policies

| File | Policy | Needs credentials? | Default |
| --- | --- | --- | --- |
| `policy-falcon-operator-install.yaml` | `policy-falcon-operator-install` — Namespaces, OperatorGroup, Subscription `falcon-operator.v1.15.0` | **No** | enabled |
| `falcon-operator-secrets-crs-policies.yaml` | `policy-falcon-secrets`, `policy-falcon-crs` | Yes (ExternalSecret → hub Secret) | **disabled** |

Bound via PlacementBinding → Policy (no PolicySet) to Placement `placement-falcon-operator` (`vendor=OpenShift`).

**Yes — the operator can install without AWS Secrets Manager / ExternalSecret.** Sensors/CRs wait until you enable the secrets+CRs file and have credentials.

---

## Best practices

1. **Prefer secrets over inline API keys** — this repo uses `falconSecret` + ACM hub templates.
2. **Pin the CSV** (`startingCSV`) and use **Manual** InstallPlan approval in production; use Automatic only if you accept channel upgrades.
3. **Do not deploy FalconContainer on OpenShift** — use FalconNodeSensor.
4. **Keep KAC in its own namespace** (`falcon-kac`) and exclude critical platform namespaces from admission failure paths (`failurePolicy: Ignore` is set for safer rollouts).
5. **Tag sensors** (`rosa-hcp`, `acm-managed`, cluster name) for Falcon grouping and dashboards.
6. **Proxy**: if the cluster has a cluster-wide proxy, OLM injects proxy env into the operator; ensure workers can still reach Falcon cloud.
7. **Uninstall order**: delete Falcon CRs first, then Subscription/CSV, then CRDs/ClusterRoles labeled by the operator, then namespaces.
8. **Validate sensor update policies** in the Falcon UI before enabling `node.advanced.autoUpdate`.
9. **Scope Placement** — start with a lab label selector before `vendor=OpenShift` across all clusters.
10. **ROSA HCP**: protecting workers is enough for the hosted control plane; guest VMs need their own sensors (below).

---

## OpenShift Virtualization (VMs)

Host nodes are covered by **FalconNodeSensor**. Guest VMs are **not** — install the Falcon sensor inside each VM OS.

See [`examples/openshift-virtualization/`](examples/openshift-virtualization/):

- **Ansible** (`crowdstrike.falcon`) — recommended for Linux/Windows guests.
- **cloud-init** example for Linux VM templates.
- Optional **nodeAffinity** overlay for `node.kubevirt.io/schedulable` workers.
- Optional **Falcon OpenShift Console Plugin** for Pod/VM security tabs in the OpenShift console.

---

## Configuration reference (common knobs)

### Subscription

```yaml
spec:
  channel: certified-1.0
  startingCSV: falcon-operator.v1.15.0
  source: certified-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Manual   # or Automatic
```

### FalconNodeSensor (OpenShift)

- `falconSecret.enabled: true` — read credentials from Secret keys `falcon-client-id`, `falcon-client-secret`, `falcon-cid`, `falcon-provisioning-token`.
- `node.tolerations: []` — worker-only (more relevant on Classic/managed with infra taints).
- `node.version` / `node.advanced.updatePolicy` — pin or follow Falcon UI update policy.
- `falcon.tags` — grouping tags.
- `falcon.aph` / `falcon.app` — sensor proxy override.

### FalconAdmission

- `registry.type: openshift` — mirror into OpenShift integrated registry (recommended on OCP).
- `registry.type: crowdstrike` — pull directly from CrowdStrike.
- `admissionConfig.failurePolicy` — `Ignore` (safer) vs `Fail` (stricter).
- `admissionConfig.disabledNamespaces` — namespaces skipped by validating webhook.

### FalconImageAnalyzer

- Requires additional API scopes (see Prerequisites).
- `registry.type: crowdstrike` by default in this repo.

---

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Policy NonCompliant on Subscription | CatalogSource `certified-operators` healthy; CSV name matches `falcon-operator.v1.15.0`. |
| InstallPlan pending | Manual approval required (step 7). |
| CRs NonCompliant / unknown type | Operator CSV not Succeeded yet; wait or approve InstallPlan. |
| Secret empty / auth errors | `ExternalSecret` Ready in `rhacm-policies`; Secret `falcon-api-credentials` exists; `secretStoreRef` / remote key correct; hub templates enabled. |
| Node sensor CrashLoop | Privileged PSA/SCC; node connectivity to Falcon; sensor version ≥ 7.40. |
| Admission webhook blocking deploys | Review `disabledNamespaces`; temporarily `failurePolicy: Ignore`. |
| Image pull failures | Network to CrowdStrike registry or OpenShift ImageStream mirror permissions. |

Operator logs:

```bash
oc -n falcon-operator logs -f deploy/falcon-operator-controller-manager -c manager
```

---

## References

- [Falcon Operator – OpenShift deployment](https://github.com/CrowdStrike/falcon-operator/blob/main/docs/deployment/openshift/README.md)
- [FalconNodeSensor](https://github.com/CrowdStrike/falcon-operator/blob/main/docs/deployment/openshift/resources/node/README.md)
- [ACM Policy Generator](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.11/html/governance/integrate-policy-generator)
- [CrowdStrike Ansible collection](https://developer.crowdstrike.com/falcon-sensor/ansible/overview/)
- [Red Hat Marketplace – Falcon OpenShift Operator](https://marketplace.crowdstrike.com/listings/red-hat-falcon-openshift-operator/)

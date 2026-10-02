# Falcon API credentials via External Secrets Operator (GitOps)
#
# Flow:
#   AWS Secrets Manager / Vault / …  →  ExternalSecret  →  K8s Secret
#   rhacm-policies/falcon-api-credentials  →  ACM hub templates  →  managed clusters
#
# ## 1. Create the remote secret with Terraform
#
#   cd terraform/aws-secretsmanager-falcon
#   export TF_VAR_falcon_client_id='...'
#   export TF_VAR_falcon_client_secret='...'
#   export TF_VAR_falcon_cid='...'
#   export TF_VAR_falcon_provisioning_token=''
#   terraform init && terraform apply
#
# Creates AWS SM secret `crowdstrike/falcon-operator` with keys:
#   falcon-client-id, falcon-client-secret, falcon-cid, falcon-provisioning-token
#
# See terraform/aws-secretsmanager-falcon/README.md
#
# ## 2. Point ExternalSecret at your existing store
#
# Edit `externalsecret-falcon-api-credentials.yaml`:
#   spec.secretStoreRef.name  → your ClusterSecretStore / SecretStore name
#   spec.secretStoreRef.kind  → ClusterSecretStore or SecretStore
#   remoteRef.key             → your remote secret path/name
#
# Do NOT recreate ClusterSecretStore here if the cluster already has one.
#
# ## 3. GitOps sync (no manual oc create secret)
#
# Option A — dedicated Argo CD Application from this repo:
#   Commit/push, then apply:
#     oc apply -f gitops/application-external-secrets.yaml
#
# Option B — drop `externalsecret-falcon-api-credentials.yaml` into your
# existing GitOps path that already syncs into `rhacm-policies` (same place
# you put falcon-operator-policies.yaml), if that path can create
# ExternalSecret CRs on the hub.
#
# ## 4. Verify
#
#   oc get externalsecret -n rhacm-policies falcon-api-credentials
#   oc get secret -n rhacm-policies falcon-api-credentials
#   # ExternalSecret status.conditions type=Ready should be True
#
# ACM policy `policy-falcon-secrets` then templates this hub Secret onto
# managed clusters as `falcon-operator/falcon-secrets`.

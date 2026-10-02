# Terraform: AWS Secrets Manager secret for Falcon Operator

Creates the remote secret consumed by External Secrets Operator:

`ExternalSecret` → `Secret/falcon-api-credentials` (`rhacm-policies`) → ACM hub templates

## Keys created

| JSON property | Purpose |
| --- | --- |
| `falcon-client-id` | CrowdStrike API client ID |
| `falcon-client-secret` | CrowdStrike API client secret |
| `falcon-cid` | Falcon CID |
| `falcon-provisioning-token` | Optional; empty string allowed |

Default secret name: `crowdstrike/falcon-operator` (matches the ExternalSecret `remoteRef.key`).

## Usage

```bash
cd terraform/aws-secretsmanager-falcon
cp terraform.tfvars.example terraform.tfvars   # optional non-secret defaults only

export TF_VAR_falcon_client_id='YOUR_CLIENT_ID'
export TF_VAR_falcon_client_secret='YOUR_CLIENT_SECRET'
export TF_VAR_falcon_cid='YOUR_CID'
export TF_VAR_falcon_provisioning_token=''

terraform init
terraform plan
terraform apply
```

Then sync `gitops/external-secrets/` so ESO materializes the Kubernetes Secret.

## IAM

The identity running Terraform needs `secretsmanager:CreateSecret`, `PutSecretValue`, `DescribeSecret`, `GetSecretValue`, `TagResource` (and delete permissions if destroying). The ESO / ClusterSecretStore role needs `GetSecretValue` / `DescribeSecret` on this secret ARN.

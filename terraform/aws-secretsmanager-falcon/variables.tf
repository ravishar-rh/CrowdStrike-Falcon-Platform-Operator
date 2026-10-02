variable "aws_region" {
  description = "AWS region for Secrets Manager"
  type        = string
  default     = "us-east-1"
}

variable "secret_name" {
  description = "Secrets Manager secret name/path. Must match ExternalSecret remoteRef.key."
  type        = string
  default     = "crowdstrike/falcon-operator"
}

variable "secret_description" {
  description = "Description stored on the AWS secret"
  type        = string
  default     = "CrowdStrike Falcon Operator API credentials for ACM / External Secrets"
}

variable "recovery_window_in_days" {
  description = "Days AWS retains a deleted secret before permanent removal (0 = force delete)"
  type        = number
  default     = 7
}

variable "falcon_client_id" {
  description = "CrowdStrike API client ID"
  type        = string
  sensitive   = true
}

variable "falcon_client_secret" {
  description = "CrowdStrike API client secret"
  type        = string
  sensitive   = true
}

variable "falcon_cid" {
  description = "CrowdStrike Falcon CID (with checksum)"
  type        = string
  sensitive   = true
}

variable "falcon_provisioning_token" {
  description = "Optional Falcon provisioning token; use empty string if unused"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "Additional tags for the secret"
  type        = map(string)
  default     = {}
}

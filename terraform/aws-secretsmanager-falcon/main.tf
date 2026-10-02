terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_secretsmanager_secret" "falcon_operator" {
  name                    = var.secret_name
  description             = var.secret_description
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    {
      Name        = var.secret_name
      Application = "crowdstrike-falcon-operator"
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

resource "aws_secretsmanager_secret_version" "falcon_operator" {
  secret_id = aws_secretsmanager_secret.falcon_operator.id
  secret_string = jsonencode({
    falcon-client-id           = var.falcon_client_id
    falcon-client-secret       = var.falcon_client_secret
    falcon-cid                 = var.falcon_cid
    falcon-provisioning-token  = var.falcon_provisioning_token
  })
}

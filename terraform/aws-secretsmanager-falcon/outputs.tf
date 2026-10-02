output "secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.falcon_operator.arn
}

output "secret_name" {
  description = "Name/path of the secret (use as ExternalSecret remoteRef.key)"
  value       = aws_secretsmanager_secret.falcon_operator.name
}

output "secret_id" {
  description = "Secrets Manager secret ID"
  value       = aws_secretsmanager_secret.falcon_operator.id
}

output "alb_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = module.alb_controller_irsa_role.iam_role_arn
}

output "alb_controller_role_name" {
  description = "Name of the IAM role for AWS Load Balancer Controller"
  value       = module.alb_controller_irsa_role.iam_role_name
}

output "external_secrets_role_arn" {
  description = "ARN of the IAM role for External Secrets Operator"
  value       = module.external_secrets_irsa_role.iam_role_arn
}

output "external_secrets_role_name" {
  description = "Name of the IAM role for External Secrets Operator"
  value       = module.external_secrets_irsa_role.iam_role_name
}

output "github_actions_policy_arn" {
  description = "ARN of the IAM policy for GitHub Actions (if enabled)"
  value       = var.enable_github_actions_role ? aws_iam_policy.github_actions[0].arn : null
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "secrets_arns" {
  description = "List of Secrets Manager ARNs that External Secrets can access"
  type        = list(string)
  default     = ["*"]
}

variable "enable_github_actions_role" {
  description = "Enable GitHub Actions OIDC role creation"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "AegisTickets"
    ManagedBy = "Terraform"
  }
}

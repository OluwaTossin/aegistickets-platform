variable "service_account_role_arn" {
  description = "ARN of the IAM role for the service account"
  type        = string
}

variable "chart_version" {
  description = "Version of the external-secrets Helm chart"
  type        = string
  default     = "0.9.11"
}

variable "eks_cluster_ready" {
  description = "Dependency to ensure EKS cluster is ready"
  type        = any
  default     = null
}

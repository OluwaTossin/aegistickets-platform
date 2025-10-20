variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  type        = string
}

variable "service_account_role_arn" {
  description = "ARN of the IAM role for the service account"
  type        = string
}

variable "chart_version" {
  description = "Version of the aws-load-balancer-controller Helm chart"
  type        = string
  default     = "1.6.2"
}

variable "eks_cluster_ready" {
  description = "Dependency to ensure EKS cluster is ready"
  type        = any
  default     = null
}

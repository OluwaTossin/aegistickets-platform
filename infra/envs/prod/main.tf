# Production Environment - Main Configuration

locals {
  cluster_name = "tickets-prod"
  common_tags = {
    Environment = var.environment
    Project     = "AegisTickets"
    ManagedBy   = "Terraform"
  }
}

# ECR Repositories (shared with dev, but included for completeness)
module "ecr" {
  source = "../../modules/ecr"
  tags   = local.common_tags
}

# EKS Cluster
module "eks" {
  source = "../../modules/eks"

  cluster_name             = local.cluster_name
  cluster_version          = "1.28"
  environment              = var.environment
  node_group_min_size      = 2
  node_group_max_size      = 6
  node_group_desired_size  = 3
  node_instance_types      = ["t3.medium"]

  tags = local.common_tags
}

# IAM Roles for Service Accounts (IRSA)
module "iam_irsa" {
  source = "../../modules/iam-irsa"

  cluster_name         = local.cluster_name
  oidc_provider_arn    = module.eks.oidc_provider_arn
  secrets_arns         = [module.rds.secret_arn]
  enable_github_actions_role = true

  tags = local.common_tags

  depends_on = [module.eks]
}

# RDS PostgreSQL
module "rds" {
  source = "../../modules/rds-postgres"

  identifier              = "tickets-prod-db"
  instance_class          = "db.t4g.medium"
  allocated_storage       = 50
  multi_az                = true
  deletion_protection     = true
  skip_final_snapshot     = false
  backup_retention_period = 14
  allowed_security_groups = [module.eks.node_security_group_id]

  tags = local.common_tags

  depends_on = [module.eks]
}

# AWS Load Balancer Controller
module "alb_controller" {
  source = "../../modules/alb-controller"

  cluster_name              = local.cluster_name
  region                    = var.aws_region
  vpc_id                    = module.eks.vpc_id
  service_account_role_arn  = module.iam_irsa.alb_controller_role_arn
  eks_cluster_ready         = module.eks.cluster_id

  depends_on = [module.iam_irsa]
}

# External Secrets Operator
module "external_secrets" {
  source = "../../modules/external-secrets"

  service_account_role_arn = module.iam_irsa.external_secrets_role_arn
  eks_cluster_ready        = module.eks.cluster_id

  depends_on = [module.iam_irsa]
}

# Monitoring Stack (Prometheus + Grafana)
module "monitoring" {
  source = "../../modules/monitoring"

  prometheus_retention         = "72h"
  prometheus_retention_size    = "15GB"
  enable_prometheus_persistence = true
  prometheus_storage_size      = "20Gi"
  grafana_admin_password       = var.grafana_admin_password
  enable_grafana_persistence   = true
  grafana_storage_size         = "10Gi"
  eks_cluster_ready            = module.eks.cluster_id

  prometheus_resources = {
    requests = {
      cpu    = "300m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }

  depends_on = [module.eks]
}

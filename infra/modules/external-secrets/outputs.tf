output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.external_secrets.name
}

output "namespace" {
  description = "Namespace where External Secrets is deployed"
  value       = kubernetes_namespace.external_secrets.metadata[0].name
}

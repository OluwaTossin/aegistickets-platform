output "namespace" {
  description = "Namespace where monitoring stack is deployed"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_release_name" {
  description = "Name of the Prometheus Helm release"
  value       = helm_release.kube_prometheus_stack.name
}

output "grafana_service_name" {
  description = "Name of the Grafana service"
  value       = "${helm_release.kube_prometheus_stack.name}-grafana"
}

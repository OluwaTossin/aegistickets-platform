output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.aws_load_balancer_controller.name
}

output "release_namespace" {
  description = "Namespace of the Helm release"
  value       = helm_release.aws_load_balancer_controller.namespace
}

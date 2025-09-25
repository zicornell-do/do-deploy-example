output "argo_app_name" {
  value       = var.app_name
  description = "Argo CD application name"
}

output "namespace" {
  value       = var.namespace
  description = "Namespace for the workload"
}

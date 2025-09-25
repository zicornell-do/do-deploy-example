variable "kubeconfig" {
  description = "Path to kubeconfig file"
  type        = string
  default     = null
}

variable "namespace" {
  description = "Namespace to deploy some-service and Argo CD app"
  type        = string
  default     = "some-service"
}

variable "argo_namespace" {
  description = "Namespace where Argo CD is installed"
  type        = string
  default     = "argocd"
}

variable "app_name" {
  description = "Argo CD application name"
  type        = string
  default     = "some-service"
}

variable "repo_url" {
  description = "Git repository URL that Argo CD will watch"
  type        = string
}

variable "repo_path" {
  description = "Path in the repo to the Helm chart"
  type        = string
  default     = "platform/apps/some-service/deploy/helm"
}

variable "target_revision" {
  description = "Git revision (branch/tag/commit)"
  type        = string
  default     = "HEAD"
}

variable "values_overrides" {
  description = "YAML values to override default chart values (as string)"
  type        = string
  default     = ""
}

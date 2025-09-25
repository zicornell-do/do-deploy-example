# Create application namespace (for workload)
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace
  }
}

# Argo CD Application CRD manifest
# This assumes Argo CD CRDs/controllers are already installed in the cluster.
# See: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/
resource "kubernetes_manifest" "argocd_app" {
  manifest = {
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "Application"
    "metadata" = {
      "name"      = var.app_name
      "namespace" = var.argo_namespace
    }
    "spec" = {
      "project" = "default"
      "source" = {
        "repoURL"        = var.repo_url
        "path"           = var.repo_path
        "targetRevision" = var.target_revision
        "helm" = (
          length(var.values_overrides) > 0 ? {
            "values" = var.values_overrides
          } : null
        )
      }
      "destination" = {
        "server"    = "https://kubernetes.default.svc"
        "namespace" = var.namespace
      }
      "syncPolicy" = {
        "automated" = {
          "prune"    = true
          "selfHeal" = true
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.app]
}

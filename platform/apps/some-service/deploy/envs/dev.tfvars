kubeconfig = null
namespace  = "some-service"
argo_namespace = "argocd"
app_name   = "some-service"
repo_url   = "https://github.com/your-org/do-deploy-example.git"
repo_path  = "platform/apps/some-service/deploy/helm"
target_revision = "HEAD"

# Example Helm values override (string). Optional.
# values_overrides = <<EOT
# image:
#   repository: your-registry/some-service
#   tag: latest
#   pullPolicy: IfNotPresent
# replicaCount: 1
# service:
#   port: 3000
# namespace: some-service
# EOT

# do-deploy-example

This repo contains:
- A minimal NestJS hello-world service at platform/apps/some-service.
- Dockerfile to containerize the service.
- Helm + Terraform configs to deploy the service (platform/apps/some-service/deploy).
- do-infra for spinning up a local kind cluster with Argo CD (installed via upstream manifest) and deploying the app via Argo CD Application.

Quick local cluster with kind + Argo CD + some-service (one command):
- From repo root:
  REPO_URL=https://github.com/your-org/do-deploy-example.git ./do-infra/deploy.sh

Then verify:
- kubectl -n some-service get pods,svc
- kubectl -n some-service port-forward svc/some-service 3000:3000
- Open http://localhost:3000 to see: Hello, World!
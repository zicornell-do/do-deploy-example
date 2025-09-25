some-service deployment configs

This directory contains a minimal setup to deploy some-service to a Kubernetes cluster using:
- Terraform: to provision Argo CD app and (optionally) namespace
- Helm: a tiny chart to template the Kubernetes manifests for the service
- Argo CD: to continuously deploy the Helm chart from this repo

Layout:
- helm/Chart.yaml                 - Minimal chart definition
- helm/values.yaml                - Default values
- helm/templates/*                - K8s resources (Deployment, Service, Namespace)
- terraform/main.tf              - Terraform to install Argo CD app pointing at this chart
- terraform/variables.tf         - Input variables
- terraform/outputs.tf           - Outputs
- terraform/providers.tf         - Providers and versions
- envs/dev.tfvars                - Example values for dev

Quick start (assumes an existing cluster and Argo CD installed):
1) Build and push image to a registry accessible by the cluster.
   export IMAGE=ghcr.io/your-org/some-service:latest
   docker build -t "$IMAGE" ../../
   docker push "$IMAGE"

2) Update envs/dev.tfvars with your repo URL and path if not using this working copy.

3) Apply Terraform to create the Argo CD Application that points to this chart:
   cd terraform
   terraform init
   terraform apply -var-file=../envs/dev.tfvars

4) Argo CD will sync the app. Verify:
   kubectl -n some-service get pods,svc

Notes:
- Keep it simple: no Ingress; access via Service ClusterIP or port-forward.
- For custom namespaces or images, set them via values and tfvars.

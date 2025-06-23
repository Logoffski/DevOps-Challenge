# Project Documentation
## Overview

This project consists of two Python-based microservices: the **Main API** and the **Auxiliary Service**, and all the required infrastructure to deploy those microservices in a kubernetes cluster. 

The Auxiliary Service integrates with AWS (S3 and SSM Parameter Store). The Main API proxies requests to it.

---

## 1. Infrastructure Management

### 1.1. Terraform Layout

The infrastructure code is organized as follows:

```
infra/
├── terraform/
│   ├── global/          # ArgoCD install and global config
│   ├── environment/     # Per-environment apps and resources
│   │   ├── apps/        # Kubernetes + IAM resources for the services
│   │   ├── resources/   # Shared environment resources (e.g., S3)
```

### 1.2. Workspaces and Provider Configuration

Terraform workspaces are used to manage separate environments:

```bash
terraform workspace new test
terraform workspace select test
```

Both modules require a workspace other than `default` before applying:

```hcl
data "assert_test" "workspace" {
  test  = terraform.workspace != "default"
  throw = "Select workspace please. terraform workspace select ***"
}
```

In addition, in order to manage AWS-based resources, valid AWS credentials have to be provided in the AWS provider configuration
```
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      env = local.environment_name
      source   = "terraform"
    }
  }
}
```

### 1.3. Global infrastructure setup

The **global** terraform module contains infrastructure that is environment-agnostic, like ArgoCD

```bash
terraform -chdir=infra/terraform/global init
terraform -chdir=infra/terraform/global apply
```

### 1.4. Environment infrastructure setup

Environment-specific resources. Provision services, IAM users, secrets, and namespaces:

```bash
terraform -chdir=infra/terraform/environment init
terraform -chdir=infra/terraform/environment workspace select test
terraform -chdir=infra/terraform/environment apply
```

---

## 2. CI/CD with GitHub Actions

### 2.1. Workflow Summary

Each service has a GitHub Actions workflow to:

- Build Docker image  
- Tag it with commit SHA  
- Push to GitHub Container Registry  
- Update `kustomization.yaml` in the repo (image tag)  
- Commit + push changes to trigger ArgoCD sync  

### 2.2. Versioning

The build injects `VERSION` via Docker `--build-arg` and stores it in the image:

```dockerfile
ARG VERSION=dev
ENV VERSION=$VERSION
```
---

## 3. Deployment with Kustomize & ArgoCD

### 3.1. Structure

```
deploy/
├── main/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── auxiliary/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
```

### 3.2. ArgoCD Applications

Defined in `infra/argocd/{main,auxiliary}.yaml` and deployed in the cluster via Terraform.

Automatically syncs changes from the repository to the cluster:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

---

## 4. Kubernetes Setup

### 4.1. Namespaces

While ArgoCD is set-up to create namespaces itself, in case more complex automation is required in the future, they are provisioned by Terraform:

- `main-api`
- `auxiliary-service`

### 4.2. Secrets

`auxiliary-service` requires AWS credentials to access AWS resources.

The secret containing required credentials is created and provided by Terraform:

```hcl
resource "kubernetes_secret" "aws_creds" {
  data = {
    AWS_ACCESS_KEY_ID     = ...
    AWS_SECRET_ACCESS_KEY = ...
    AWS_REGION            = ...
  }
}
```

---

## 5. AWS Integration

### 5.1. IAM User

Terraform creates a per-environment IAM user (`${env}-app-service-user`) and access keys.

### 5.2. Permissions

Minimal read-only access to:

- Specific S3 buckets: `arn:aws:s3:::${env}-apps-main`
- SSM Parameter Store: `/${env}/apps/*`
- KMS decrypt for SSM

In addition, the user has access to:
- List All s3 buckets in the AWS account
- List all parameters in Parameter Store

### 5.3. SSM Parameters

Access keys for the created user are also saved in the Parameter Store:

```
/${env}/service_user/access_key_id
/${env}/service_user/secret_access_key
```
Neither service has access to those parameters.

---

## 6. Application Code

### 6.1. Auxiliary Service

Exposes:

- `/healthz`  
- `/readyz` (tests SSM access)  
- `/buckets` (lists S3 buckets)  
- `/parameters` (lists SSM parameters)  
- `/parameter?name=...` (fetches SSM parameter)  

### 6.2. Main API

Forwards requests to Auxiliary:

- `/buckets` → `/buckets`  
- `/parameters` → `/parameters`  
- `/parameter` → `/parameter`  

Both report their `VERSION` in the response.

---

## 7. Local Development

### 7.1. Minikube Setup

Ensure your `~/.kube/config` is using:

```yaml
config_context: "minikube"
```

### 7.2. Local Apply

```bash
# Global setup
terraform -chdir=infra/terraform/global apply

# Environment setup
terraform -chdir=infra/terraform/environment workspace new dev
terraform -chdir=infra/terraform/environment apply
```

---

## 8. API Usage Examples

### 8.1. Health Checks

```http
GET /healthz
→ { "status": "ok" }

GET /readyz
→ { "status": "ready" }
```

### 8.2. S3 Buckets

```http
GET /buckets
→ {
  "main_version": "abc123",
  "auxiliary_version": "abc123",
  "buckets": ["my-bucket"]
}
```

### 8.3. SSM Parameters

```http
GET /parameters

GET /parameter?name=/test/apps/FOO
```

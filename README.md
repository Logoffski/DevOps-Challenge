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

The **global** terraform module contains infrastructure that is environment-agnostic.

For the purposes of the code-challenge, only ArgoCD is created in this module:

```bash
terraform -chdir=infra/terraform/global init
terraform -chdir=infra/terraform/global apply
```

### 1.4. Environment infrastructure setup

The **environment* module contains environment-specific resources. 

Provisions services, IAM users, secrets, and namespaces:

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
- List all S3 buckets in the AWS account
- List all parameters in the Parameter Store

### 5.3. SSM Parameters

Access keys for the created user are additionally saved in the Parameter Store:

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

The following documentation assumes you already have an AWS account and a working, accessible kubernetes cluster deployed and set as your current `kubectl` context.

### 7.1. Terraform Setup

Configure AWS provider in both **global** and **environment** modules:

The code is designed to use your local cached IAM credentials, created via `aws sso configure` and `aws sso login --profile "yourprofilename"`

To use your profile, create a terraform.tfvars file in both modules with the following inside:
```hcl
aws_profile = "yourprofilename"
```
Alternatively, you can use any other authentication method supported by the AWS provider.

Lastly, change `aws_region` in `variables.tf` in both root modules to your desired region.

### 7.2. Local Apply

```bash
# Global setup
terraform -chdir=infra/terraform/global workspace new global
terraform -chdir=infra/terraform/global apply

# Environment setup
terraform -chdir=infra/terraform/environment workspace new test
terraform -chdir=infra/terraform/environment apply
```

### 7.3. ArgoCD setup

In case you want to clone this repository and use your own images, replace the repository in the following files:

`deploy/{main,auxiliary}/deployment.yaml`
```
    spec:
      containers:
        - name: auxiliary-service
          image: ghcr.io/${REPO_OWNER}/${IMAGE_NAME}:latest
          ports:
            - containerPort: 8001
```
`infra/argocd/{main,auxiliary}.yaml`
```
spec:
  project: default
  source:
    repoURL: https://github.com/${REPO_OWNER}/${REPO_NAME}.git
    targetRevision: HEAD
    path: deploy/main
```

### 7.4 Network setup
Both applications and ArgoCD have a Kubernetes Service with type **ClusterIP** for ease of use in production scenarios when an ingress/ingress-controller is present.

For local development, the recommended approach is to port-forward both **ArgoCD** and **main-api** to your local machine:

```bash
kubectl port-forward -n argocd svc/argocd-server 8081:443
kubectl port-forward -n main-api service/main-api 8080:80
```
---

## 8. API Usage & Examples

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

### 8.4. Request examples

```bash
curl http://localhost:8080/parameter?name=/test/apps/config/env_name
{"auxiliary_version":"05381237521317c714dd0cf8eaf6d7268d889715","main_version":"05381237521317c714dd0cf8eaf6d7268d889715","name":"/test/apps/config/env_name","value":"test"}

curl http://localhost:8080/buckets
{"auxiliary_version":"05381237521317c714dd0cf8eaf6d7268d889715","buckets":["test-apps-main","test-apps-secondary"],"main_version":"05381237521317c714dd0cf8eaf6d7268d889715"}

curl http://localhost:8080/parameters
{"auxiliary_version":"05381237521317c714dd0cf8eaf6d7268d889715","main_version":"05381237521317c714dd0cf8eaf6d7268d889715","parameters":["/test/apps/config/env_name","/test/apps/config/hotel","/test/apps/config/locale","/test/service_user/access_key_id","/test/service_user/secret_access_key"]}
```

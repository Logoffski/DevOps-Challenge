## Kubernetes namespaces

resource "kubernetes_namespace" "main_api" {
  metadata {
    name = "main-api" ## in real production, namespace's name actually should include the environment name, but doing that would require more complex logic
  }
}

resource "kubernetes_namespace" "auxiliary" {
  metadata {
    name = "auxiliary-service"
  }
}

## ArgoCD Manifests

resource "kubernetes_manifest" "main_api" {
  depends_on = [ kubernetes_namespace.main_api ]
  manifest = yamldecode(file("${path.module}/../../../argocd/main.yaml"))
}

resource "kubernetes_manifest" "auxiliary" {
  depends_on = [ kubernetes_namespace.auxiliary, kubernetes_secret.aws_creds ]
  manifest = yamldecode(file("${path.module}/../../../argocd/auxiliary.yaml"))
}

## Required kubernetes secrets

resource "kubernetes_secret" "aws_creds" {
  metadata {
    name      = "aws-creds"
    namespace = kubernetes_namespace.auxiliary.metadata[0].name
  }

  data = {
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.app_service_user.id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.app_service_user.secret
    AWS_REGION            = var.aws_region
  }

  type = "Opaque"
}
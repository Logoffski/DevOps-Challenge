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
  depends_on = [ kubernetes_namespace.auxiliary ]
  manifest = yamldecode(file("${path.module}/../../../argocd/auxiliary.yaml"))
}
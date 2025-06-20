resource "kubernetes_namespace" "main_api" {
  metadata {
    name = "main-api"
  }
}
resource "kubernetes_manifest" "main_api" {
  manifest = yamldecode(file("${path.module}/../../../argocd/main.yaml"))
}

resource "kubernetes_namespace" "auxiliary" {
  metadata {
    name = "auxiliary-service"
  }
}
resource "kubernetes_manifest" "auxiliary" {
  manifest = yamldecode(file("${path.module}/../../../argocd/aux.yaml"))
}
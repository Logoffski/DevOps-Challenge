resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "8.1.1"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  ## Run "minikube service -n argocd argocd-server" on windows host to access the UI
  set {
    name  = "server.service.type"
    value = "NodePort"
  }

}

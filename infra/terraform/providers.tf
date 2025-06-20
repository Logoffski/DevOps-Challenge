terraform {
  required_version = ">= 1.6.1"

  backend "local" {
    path = "terraform.tfstate" 
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    assert = {
        source = "bwoznicki/assert"
        version = "0.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.12.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "minikube"
    #insecure       = true
  }
}

provider "kubectl" {
    load_config_file = true
    }

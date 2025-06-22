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

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  profile = "AdministratorAccess-487410309821"
  default_tags {
    tags = {
      env = local.environment_name
      source   = "terraform"
    }
  }
}


provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

provider "kubectl" {
    load_config_file = true
}

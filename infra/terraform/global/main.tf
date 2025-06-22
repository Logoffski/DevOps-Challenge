locals {
  environment_name = "global"
}


data "assert_test" "workspace" {
  test  = terraform.workspace != "default"
  throw = "Select workspace please. terraform worspace select ***"
}

module "argocd" {
  source                = "./ArgoCD"
}

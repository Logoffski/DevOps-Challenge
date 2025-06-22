locals {
  environment_name = terraform.workspace
  s3_buckets = ["main", "secondary"]
}

data "aws_caller_identity" "current" {} 

data "assert_test" "workspace" {
  test  = terraform.workspace != "default"
  throw = "Select workspace please. terraform workspace select ***"
}

module "environment_apps" {
  source = "./apps"
  aws_region = var.aws_region
  environment_name = local.environment_name
  s3_bucket_names = local.s3_buckets
  aws_account_id = data.aws_caller_identity.current.account_id
}

module "environment_resources" {
  source = "./resources"
  environment_name = local.environment_name
  s3_bucket_names = local.s3_buckets
}

## S3 buckets

resource "aws_s3_bucket" "buckets" {
  for_each = toset(var.s3_bucket_names)
  bucket = "${var.environment_name}-apps-${each.value}"
}

resource "aws_s3_bucket_public_access_block" "acl_block" {
for_each = aws_s3_bucket.buckets
  bucket = aws_s3_bucket.buckets[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

## Parameter Store

resource "aws_ssm_parameter" "test_keys_please_ignore" {
  for_each = {
    "locale" = "en",
    "env_name" = "${var.environment_name}",
    "hotel" = "Trivago"
  }

  name  = "/${var.environment_name}/apps/config/${each.key}"
  type  = "String"
  value = each.value
}
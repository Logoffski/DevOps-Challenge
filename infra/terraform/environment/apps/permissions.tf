## Application service accounts and permissions

resource "aws_iam_user" "app_service_user" {
  name = "${var.environment_name}-app-service-user"
}

resource "aws_iam_access_key" "app_service_user" {
  user = aws_iam_user.app_service_user.name
}

resource "aws_iam_user_policy" "s3_read_only" {
  name = "s3-read-only-policy"
  user = aws_iam_user.app_service_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      ## Allow listing all buckets
      {
        Action   = ["s3:ListAllMyBuckets"]
        Effect   = "Allow"
        Resource = "*"
      },
      ## Allow listing and reading from a specific bucket
      {
        Action = [
          "s3:ListBucket",      
          "s3:GetObject",       
          "s3:GetObjectVersion" 
        ]
        Effect = "Allow"
        Resource = flatten([
          for name in var.s3_bucket_names : [
            "arn:aws:s3:::${var.environment_name}-apps-${name}",
            "arn:aws:s3:::${var.environment_name}-apps-${name}/*"
          ]
        ])
      }
    ]
  })
}

resource "aws_iam_user_policy" "ssm_read_only" {
  name = "ssm-read-only-policy"
  user = aws_iam_user.app_service_user.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        ## Allow listing ALL parameters in the AWS account
        Action   = "ssm:DescribeParameters",
        Effect   = "Allow",
        Resource = "*",
      },
      {
        ## Allow reading values from "/env_name/apps/*" 
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"],
        Effect   = "Allow",
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.environment_name}/apps/*" 
      },
      ## Allow decrypting secrets
      {
        Action   = ["kms:Decrypt"]
        Effect   = "Allow"
        Resource = [
          "arn:aws:kms:${var.aws_region}:${var.aws_account_id}:key/alias/aws/ssm"
        ]
      },
    ]
  })
}

resource "aws_ssm_parameter" "access_key_id" {
  name  = "/${var.environment_name}/service_user/access_key_id"
  type  = "String"  
  value = aws_iam_access_key.app_service_user.id
}

resource "aws_ssm_parameter" "secret_access_key" {
  name  = "/${var.environment_name}/service_user/secret_access_key"
  type  = "SecureString" 
  value = aws_iam_access_key.app_service_user.secret
}
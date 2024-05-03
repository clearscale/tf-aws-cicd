#
# KMS key for the CodeCommit bucket
# CodeCommit, CodePipeline, and CodeBuild should be able to use this key.
#
module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "2.0.1"

  deletion_window_in_days = 7
  description             = "${var.project} CI/CD pipeline key."
  enable_key_rotation     = true
  is_enabled              = true
  key_usage               = "ENCRYPT_DECRYPT"
  multi_region            = false
  aliases                 = ["${local.prefix}-cicd"]
  aliases_use_name_prefix = true
  enable_default_policy   = true

  key_owners = flatten([
    ["arn:aws:iam::${local.account_id}:root"],
    (distinct([for owner in var.kms.owners : owner
      if owner != null
    ])),
  ])
  key_administrators = flatten([
    ["arn:aws:iam::${local.account_id}:root"],
    (distinct([for admin in var.kms.admins : admin
      if admin != null
    ])),
  ])
  key_users = flatten([
    ["arn:aws:iam::${local.account_id}:root"],
    (distinct([for user in var.kms.users : user
      if user != null
    ])),
  ])

  key_statements = [
    {
      sid = "AllowS3ToUseKey"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]

      principals = [{
        type        = "AWS"
        identifiers = ["*"]
      }]

      conditions = [{
        test     = "StringEquals"
        variable = "kms:ViaService"
        values = [
          "s3.${var.region}.amazonaws.com"
        ]
      },
      {
        test     = "StringEquals"
        variable = "kms:CallerAccount"
        values = distinct([
          local.account_id,
          local.account_id_repo,
        ])
      }]
    },{
      sid = "AllowDevOpsServices"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]

      principals = [{
        type        = "Service"
        identifiers = [
          "codecommit.amazonaws.com",
          "codepipeline.amazonaws.com",
          "codebuild.amazonaws.com",
          "codedeploy.amazonaws.com"
        ]
      }]

      conditions = [{
        test     = "StringEquals"
        variable = "kms:CallerAccount"
        values = distinct([
          local.account_id,
          local.account_id_repo,
        ])
      }]
    }
  ]
}
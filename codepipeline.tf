#
# Local variables specifically for CodePipeline
#
locals {
  modified_stages = [
    for stage in var.stages : merge(
      stage,
      {
        action = merge(
          stage.action,
          {
            name        = module.aws_cicd_codebuild[stage.name].name
            role_arn    = module.aws_cicd_codebuild[stage.name].role.arn
            stage_roles = module.aws_cicd_codebuild[stage.name].stage_roles
            configuration = {
              ProjectName = module.aws_cicd_codebuild[stage.name].name
            }
          }
        )
      }
    )
  ]
}

#
# Dependency (chicken-and-egg) issue:
# The CodePipeline IAM role must be created first. 
# CodeCommit must trust CodePipeline, but AWS disallows trusting non-existent roles.
# We can, however, add non-existent ARNs to IAM policies, just not trust relationships.
#
# Thus:
#   a. Create the CodePipeline role with a generated (yet non-existent) CodeCommit ARN.
#   b. Then, establish the CodeCommit role trusting CodePipeline.
#   c. Finally, deploy the remaining resources.
#
module "aws_cicd_codepipeline_iam" {
  source  = "../tf-aws-cicd-codepipeline/iam"
  client  = var.client
  project = var.project
  env     = var.env
  account = var.account
  region  = var.region
  name    = var.name
  prefix  = local.prefix

  artifact_stores = [{
    type     = "S3"
    location = module.s3_bucket.s3_bucket_arn
  }]

  repo = {
    name = "Source"
    action = {
      role_arn = var.repo.role_arn
      configuration = {
        RepositoryName  = var.repo.name
        BranchName      = var.repo.branch
        EncryptionKey   = module.kms.key_arn
      }
    }
  }

  stages = local.modified_stages
}

#
# Deploy the actual pipeline resource
#
module "aws_cicd_codepipeline" {
  source  = "../tf-aws-cicd-codepipeline"
  client  = var.client
  project = var.project
  env     = var.env
  account = var.account
  region  = var.region
  name    = var.name
  prefix  = local.prefix
  role    = module.aws_cicd_codepipeline_iam.role.arn

  artifact_stores = [{
    type           = "S3"
    location       = module.s3_bucket.s3_bucket_arn
    region         = var.region
    encryption_key = module.kms.key_arn
  }]

  repo = {
    name = "Source"
    action = {
      role_arn = var.repo.role_arn
      configuration = {
        RepositoryName  = var.repo.name
        BranchName      = var.repo.branch
        EncryptionKey   = module.kms.key_arn
      }
    }
  }

  stages = local.modified_stages
}
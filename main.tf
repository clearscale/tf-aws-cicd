#
# Import standardization module
#
module "std" {
  source =  "github.com/clearscale/tf-standards.git?ref=v1.0.0"

  prefix   = var.prefix
  client   = var.client
  project  = var.project
  accounts = [var.account]
  env      = var.env
  region   = var.region
  name     = var.name
}

#
# There is a circular dependency between CodeBuild and CodePipeline.
# To prevent this, we will just generate the IAM role and policy
# names created by the CodePipeline module the same way that the module
# does.
#
module "std_codepipeline" {
  source =  "github.com/clearscale/tf-standards.git?ref=v1.0.0"

  prefix   = var.prefix
  client   = var.client
  project  = var.project
  accounts = [var.account]
  env      = var.env
  region   = var.region
  name     = var.name
  function = var.repo.name
}
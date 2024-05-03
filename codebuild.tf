#
# Create CodeBuild resources from var.stages
#
module "aws_cicd_codebuild" {
  source   = "../tf-aws-cicd-codebuild"
  for_each = { for s in local.stages_cb : s.name => s }
  client   = var.client
  project  = var.project
  env      = var.env
  account  = var.account
  prefix   = local.prefix
  name     = each.value.name

  iam_codepipeline = [
    "arn:aws:iam::${local.account_id}:role/${module.std_codepipeline.names.aws[var.account.name].title}",
    "arn:aws:iam::${local.account_id}:policy/${module.std_codepipeline.names.aws[var.account.name].title}"
  ]

  encryption_key = (
    module.kms.key_arn
  )

  region = (each.value.resource.region == null
    ? var.region
    : each.value.resource.region
  )

  project_name = format("%s-%s-%s",
    local.prefix,
    local.env,
    try(each.value.action.configuration.ProjectName, each.value.name)
  )

  description = (each.value.resource.description == null
    ? null
    : each.value.resource.description
  )

  cache = {
    type     = "S3"
    modes    = null
    location = "${module.s3_bucket.s3_bucket_arn}/${local.env}/cache/${local.name}"
  }

  script = (each.value.resource.script == null
    ? null
    : each.value.resource.script
  )

  iam_service_role_policies = (each.value.resource.iam_service_role_policies == null
    ? (var.iam_service_role_policies == null
      ? []
      : var.iam_service_role_policies
    ): concat(
      var.iam_service_role_policies,
      each.value.resource.iam_service_role_policies
    )
  )
  
  compute = (each.value.resource.compute == null
    ? {}
    : each.value.resource.compute
  )

  vpc = (each.value.resource.vpc != null
    ? each.value.resource.vpc :
    {
      id              = var.vpc.id
      subnets         = var.vpc.subnets
      security_groups = var.vpc.security_groups
    }
  )

  repo = {
    name     = local.repo_account.name
    provider = "CodeCommit"
    region   = var.region
    role_arn = var.repo.role_arn
  }

  secrets = concat(var.secrets, each.value.secrets)
  logs    = each.value.logs
  stages  = var.stages
}
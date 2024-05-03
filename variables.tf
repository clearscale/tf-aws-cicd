locals {
  client       = lower(replace(var.client, " ", "-"))
  project      = lower(replace(var.project, " ", "-"))
  account_name = lower(trimspace(replace(var.account.name, "-", "")))
  envname      = lower(trimspace(var.env))
  region       = lower(replace(replace(var.region, " ", "-"), "-", ""))
  name         = lower(replace(var.name, " ", "-"))

  prefix = (try(
    trimspace(var.prefix),
    "${local.client}-${local.project}")
  )

  bucket_name = module.std.names.aws[var.account.name].general

  account_id = (var.account.id != "*"
    ? var.account.id
    : data.aws_caller_identity.current.account_id
  )

  repo_account = (var.repo.account == null
    ? var.account
    : var.repo.account
  )

  account_id_repo = ((
    local.repo_account != "*" &&
    local.repo_account != local.account_id
  )
    ? local.repo_account.id
    : null
  )

  account_id_repo_canonical = ((
    local.repo_account != "*" &&
    local.repo_account != local.account_id
  )
    ? try(var.repo.account.id_canonical, null)
    : null
  )

  env = (local.envname == "default" && terraform.workspace == "default"
    ? "dev"
    : local.envname
  )

  cache = ((
    local.name == null || local.name == "" || local.name == "default"
  ) ? "${local.bucket_name}/${local.env}/cache/default"
    : "${local.bucket_name}/${local.env}/cache/${local.name}"
  )

  stages_cb = [
    for s in var.stages : s if s.action.provider == "CodeBuild"
  ]

  # dependency_cb = (length(local.stages_cb) > 0
  #   ? module.aws_cicd_codebuild
  #   : null
  # )

  prefix_title = replace(title(
    replace("${local.prefix}.${local.account_name}.${local.region}.${local.env}", "-", " ")
  ), " ", "")

  prefix_iam_codecommit = replace(title(
    replace("${local.prefix_title}.CodeCommit.${local.name}.", "-", " ")
  ), " ", "")

  prefix_iam_codepipeline = replace(title(
    replace("${local.prefix_title}.CodePipeline.${local.name}.", "-", " ")
  ), " ", "")
}

variable "prefix" {
  type        = string
  description = "(Optional). Prefix override for all generated naming conventions."
  default     = null
}

variable "client" {
  type        = string
  description = "(Optional). Name of the client"
  default     = "ClearScale"
}

variable "project" {
  type        = string
  description = "(Optional). Name of the client project."
  default     = "int"
}

variable "account" {
  description = "(Required). Cloud provider account object."
  type = object({
    key      = optional(string, "current")
    provider = optional(string, "aws")
    id       = optional(string, "*") 
    name     = string
    region   = optional(string, null)
  })
  default = {
    id   = "*"
    name = "shared"
  }
}

variable "env" {
  type        = string
  description = "(Optional). Name of the current environment."
  default     = "dev"
}

variable "region" {
  type        = string
  description = "(Optional). Name of the region."
  default     = "us-west-1"
}

variable "name" {
  type        = string
  description = "(Optional). The name of the pipeline."
  default     = "default"
}

variable "kms" {
  description = "(Optional). KMS key settings."
  type = object({
    owners = optional(list(string), [])
    admins = optional(list(string), [])
    users  = optional(list(string), [])
  })
  default = {}
}

#
# Additional IAM policy ARNs.
# These will be applied to all stages that accept additional
# IAM policies such as CodeBuild.
#
# Example:
#   iam_assume_role_policies = ["arn:aws:iam::aws:policy/PowerUserAccess"]
#
variable "iam_service_role_policies" {
  description = "(Optional). List of IAM policy ARNs to attach to the primary service roles."
  type        = list(string)
  default     = []
}

#
# Networking configuration for CICD pipelines in AWS
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project#vpc_config
#
variable "vpc" {
  description = "(Required). Global VPC configuration for the CodeBuild projects where they are not specifically defined."
  type = object({
    id              = string       # vpc id
    subnets         = list(string) # ids
    security_groups = list(string) # ids
  })
}

#
# Code repository definitions
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline#stage
#
variable "repo" {
  description = "(Required). Repository URL and branch name."
  type = object({
    name     = string
    branch   = string
    role_arn = string
    kms_key = optional(string, null)
    account = optional(object({
      id           = optional(number, null)
      id_canonical = optional(string, null)
      name         = optional(string, null)
    }), null)
  })
}

#
# Secrets that *all* CodeBuild projects in var.stages will have access to.
#
variable "secrets" {
  description = "(Optional). List of secret names that are stored in Secrets Manager which CodeBuild should be able to read."
  type        = list(string)
  default     = []
}

#
# A list of stages and their parameters.
# Will skip "Source" stages if var.repo != null.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline#stage
#
variable "stages" {
  description = "(Required). List of stages for CodePipeline. configuration.ProjectName is required."
  type = list(object({
    name   = string
    action = object({
      name            = optional(string, "Build")
      category        = optional(string, "Build")
      provider        = optional(string, "CodeBuild")
      version         = optional(string, "1")
      owner           = optional(string, "AWS")
      region          = optional(string, null)
      input_artifacts = optional(list(string), null)
      configuration   = optional(object({
        ProjectName = string
      }), null)
    })
    resource = object({
      region                    = optional(string, null)
      name                      = optional(string, null)
      description               = optional(string, null)
      script                    = optional(string, null)
      iam_service_role_policies = optional(list(string), [])

      # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project#environment
      # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
      compute = optional(object({
        compute_type = optional(string, "BUILD_GENERAL1_SMALL")
        image        = optional(string, "aws/codebuild/amazonlinux2-x86_64-standard:5.0")
        type         = optional(string, "LINUX_CONTAINER")
      }))

      # Inherits var.vpc if not set.
      vpc = optional(object({
        id              = optional(string,       null) # vpc id
        subnets         = optional(list(string), null) # ids
        security_groups = optional(list(string), null) # ids
      }), null)
    })
    secrets = optional(list(string), [])
    logs    = optional(list(string), [])
  }))
}
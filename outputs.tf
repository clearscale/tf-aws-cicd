output "name" {
  description = "The name of the CICD resources."
  value       = local.name
}

output "cache" {
  description = "Location path for the cached resources."
  value       = local.cache
}

output "s3" {
  description = "KMS related data"
  value = {
    arn  = module.s3_bucket.s3_bucket_arn
    name = local.bucket_name
  }
}

output "codepipeline" {
  description = "All CodePipeline outputs."
  value       = [for cp in module.aws_cicd_codepipeline : cp]
}


output "codebuild" {
  description = "All CodeBuild outputs."
  value       = [for cb in module.aws_cicd_codebuild : cb]
}

output "kms" {
  description = "KMS related data."
  value = {
    arn     = module.kms.key_arn
    id      = module.kms.key_id
    aliases = module.kms.aliases
  }
}
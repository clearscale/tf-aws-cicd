#
# Create and manage an S3 bucket for CICD pipelines.
# Cache, assets, and SCM repository files will use this bucket.
#
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.15.1"

  bucket = local.bucket_name

  versioning = {
    enabled = false
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = module.kms.key_arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"
  attach_policy            = true
  force_destroy            = true # Allow deletion of non-empty bucket
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = [
            var.repo.role_arn,
            module.aws_cicd_codepipeline_iam.role.arn,
          ]
        },
        Action = [
          "s3:ListBucket",
          #"s3:ListBuckets",
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetBucketVersioning",
          "s3:GetBucketAcl",
          "s3:GetLifecycleConfiguration",
          "s3:GetBucketOwnershipControls",
          "s3:GetBucketPolicy",
          "s3:GetObjectVersion",
          "s3:ListMultipartUploadParts",
          "s3:PutObjectAcl",
          "s3:PutObjectVersionAcl",
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion"
        ],
        Resource = [
          "arn:aws:s3:::${local.bucket_name}",
          "arn:aws:s3:::${local.bucket_name}/*"
        ],
        "Condition": {
          "StringEquals": {
            "aws:SourceAccount": distinct([
              local.account_id,
              local.account_id_repo,
            ])
          }
        }
      }
    ]
  })

  # Sometimes only explict ACL grants work for cross account setups
  # Enable cross-account support.
  acl   = null
  grant = (local.account_id_repo != null && (local.account_id != local.account_id_repo) ? [{
      type       = "CanonicalUser"
      permission = "FULL_CONTROL"
      id         = data.aws_canonical_user_id.current.id
    },{
      type       = "CanonicalUser"
      permission = "READ"
      id         = coalesce(local.account_id_repo_canonical, data.aws_canonical_user_id.current.id)
    },{
      type       = "CanonicalUser"
      permission = "WRITE"
      id         =coalesce(local.account_id_repo_canonical, data.aws_canonical_user_id.current.id)
    },{
      type       = "CanonicalUser"
      permission = "READ_ACP"
      id         =coalesce(local.account_id_repo_canonical, data.aws_canonical_user_id.current.id)
    }
  ] : [])
}
#
# Set providers and versions.
# These values must be hardcoded. We can't use variables here.
# https://developer.hashicorp.com/terraform/language/providers/requirements
# https://registry.terraform.io/browse/providers
#
terraform {
  required_version = ">= 1.6.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#
# Current AWS context from the primary provider
#
data "aws_caller_identity" "current" {}

#
# Current AWS Account's canonical user ID
# https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-identifiers.html#FindCanonicalId
#
data "aws_canonical_user_id" "current" {}

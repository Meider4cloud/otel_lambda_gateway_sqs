terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "ProjectAdmin-339712788047"
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Archive lambda functions
data "archive_file" "lambda1_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda1"
  output_path = "${path.module}/lambda1.zip"
}

data "archive_file" "lambda2_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda2"
  output_path = "${path.module}/lambda2.zip"
}


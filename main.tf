terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = "test"
  secret_key = "test"

  # No real AWS account exists behind LocalStack, so skip checks that call real AWS.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # LocalStack serves buckets at localhost:4566/<bucket>, not <bucket>.localhost.
  s3_use_path_style = true

  endpoints {
    s3       = var.localstack_endpoint
    dynamodb = var.localstack_endpoint
    sqs      = var.localstack_endpoint
  }
}

resource "aws_s3_bucket" "storage" {
  bucket = "${var.project_name}-${var.environment}-storage"

  tags = {
    Environment = var.environment
  }
}

resource "aws_dynamodb_table" "records" {
  name         = "${var.project_name}-${var.environment}-records"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "jobs" {
  name = "${var.project_name}-${var.environment}-jobs"

  tags = {
    Environment = var.environment
  }
}

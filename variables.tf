variable "aws_region" {
  description = "AWS region to simulate. LocalStack accepts any valid region name."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used when naming resources."
  type        = string
  default     = "meridian"
}

variable "environment" {
  description = "Environment name, used in resource names and tags."
  type        = string
  default     = "dev"
}

variable "localstack_endpoint" {
  description = "URL where LocalStack is listening."
  type        = string
  default     = "http://localhost:4566"
}

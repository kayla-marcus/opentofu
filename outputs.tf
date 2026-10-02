output "bucket_name" {
  description = "Name of the S3 bucket."
  value       = aws_s3_bucket.storage.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.storage.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table."
  value       = aws_dynamodb_table.records.name
}

output "sqs_queue_url" {
  description = "URL of the SQS queue."
  value       = aws_sqs_queue.jobs.url
}

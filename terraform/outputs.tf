# Storage Outputs
output "raw_bucket_name" {
  description = "Name of the raw S3 bucket"
  value       = module.storage.raw_bucket_name
}

output "raw_bucket_arn" {
  description = "ARN of the raw S3 bucket"
  value       = module.storage.raw_bucket_arn
}

output "processed_bucket_name" {
  description = "Name of the processed S3 bucket"
  value       = module.storage.processed_bucket_name
}

output "processed_bucket_arn" {
  description = "ARN of the processed S3 bucket"
  value       = module.storage.processed_bucket_arn
}

output "deployment_bucket_name" {
  description = "Name of the deployment S3 bucket"
  value       = module.storage.deployment_bucket_name
}

# Database Outputs
output "db_endpoint" {
  description = "RDS database endpoint"
  value       = module.database.db_endpoint
}

output "db_port" {
  description = "RDS database port"
  value       = module.database.db_port
}

output "db_instance_id" {
  description = "RDS database instance ID"
  value       = module.database.db_instance_id
}

output "db_security_group_id" {
  description = "RDS database security group ID"
  value       = module.database.db_security_group_id
}

# Compute Outputs
output "ingestion_lambda_name" {
  description = "Name of the ingestion Lambda function"
  value       = module.compute.ingestion_lambda_name
}

output "ingestion_lambda_arn" {
  description = "ARN of the ingestion Lambda function"
  value       = module.compute.ingestion_lambda_arn
}

output "processing_lambda_name" {
  description = "Name of the processing Lambda function"
  value       = module.compute.processing_lambda_name
}

output "processing_lambda_arn" {
  description = "ARN of the processing Lambda function"
  value       = module.compute.processing_lambda_arn
}

# Security Outputs
output "ingestion_lambda_role_arn" {
  description = "ARN of the ingestion Lambda IAM role"
  value       = module.security.ingestion_lambda_role_arn
}

output "processing_lambda_role_arn" {
  description = "ARN of the processing Lambda IAM role"
  value       = module.security.processing_lambda_role_arn
}

# Orchestration Outputs
output "step_function_name" {
  description = "Name of the main Step Functions state machine"
  value       = module.orchestration.step_function_name
}

output "step_function_arn" {
  description = "ARN of the main Step Functions state machine"
  value       = module.orchestration.step_function_arn
}

output "manual_step_function_name" {
  description = "Name of the manual Step Functions state machine"
  value       = module.orchestration.manual_step_function_name
}

output "manual_step_function_arn" {
  description = "ARN of the manual Step Functions state machine"
  value       = module.orchestration.manual_step_function_arn
}

output "error_recovery_step_function_name" {
  description = "Name of the error recovery Step Functions state machine"
  value       = module.orchestration.error_recovery_step_function_name
}

output "error_recovery_step_function_arn" {
  description = "ARN of the error recovery Step Functions state machine"
  value       = module.orchestration.error_recovery_step_function_arn
}

# Monitoring Outputs
output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_name
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_url
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = module.monitoring.sns_topic_arn
}

# Core Infrastructure Outputs
output "name_prefix" {
  description = "Standardized name prefix"
  value       = module.core_infrastructure.name_prefix
}

# Combined Output for Easy Access
output "infrastructure_summary" {
  description = "Summary of all deployed infrastructure"
  value = {
    storage = {
      raw_bucket      = module.storage.raw_bucket_name
      processed_bucket = module.storage.processed_bucket_name
      deployment_bucket = module.storage.deployment_bucket_name
    }
    database = {
      endpoint = module.database.db_endpoint
      port     = module.database.db_port
      instance_id = module.database.db_instance_id
    }
    compute = {
      ingestion_lambda = module.compute.ingestion_lambda_name
      processing_lambda = module.compute.processing_lambda_name
    }
    orchestration = {
      main_step_function = module.orchestration.step_function_name
      manual_step_function = module.orchestration.manual_step_function_name
      error_recovery_step_function = module.orchestration.error_recovery_step_function_name
    }
    monitoring = {
      dashboard = module.monitoring.dashboard_name
      dashboard_url = module.monitoring.dashboard_url
    }
  }
}

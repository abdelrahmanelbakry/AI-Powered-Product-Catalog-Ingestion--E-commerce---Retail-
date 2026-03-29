variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "product-catalog"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "product-catalog"
    ManagedBy   = "terraform"
    Environment = "dev"
  }
}

# Database Configuration
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "productcatalog"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "Initial allocated storage for RDS (GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for RDS (GB)"
  type        = number
  default     = 100
}

variable "db_backup_retention_period" {
  description = "Backup retention period for RDS (days)"
  type        = number
  default     = 7
}

# Network Configuration
variable "vpc_id" {
  description = "VPC ID for RDS deployment"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for RDS deployment"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for RDS"
  type        = list(string)
  default     = []
}

variable "db_subnet_cidr_blocks" {
  description = "CIDR blocks allowed to access RDS"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

# Lambda Configuration
variable "lambda_timeout" {
  description = "Lambda function timeout (seconds)"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Lambda function memory size (MB)"
  type        = number
  default     = 512
}

variable "lambda_reserved_concurrent_executions" {
  description = "Reserved concurrent executions for Lambda"
  type        = number
  default     = null
}

# Bedrock Configuration
variable "bedrock_model" {
  description = "Bedrock model ID for AI processing"
  type        = string
  default     = "anthropic.claude-v2"
}

variable "bedrock_max_tokens" {
  description = "Maximum tokens for Bedrock responses"
  type        = number
  default     = 2000
}

# Step Functions Configuration
variable "step_function_timeout" {
  description = "Step Functions execution timeout (seconds)"
  type        = number
  default     = 3600
}

# Monitoring Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention period (days)"
  type        = number
  default     = 14
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

# S3 Configuration
variable "s3_versioning" {
  description = "Enable S3 versioning"
  type        = bool
  default     = true
}

variable "s3_lifecycle_days" {
  description = "S3 lifecycle transition days"
  type        = number
  default     = 30
}

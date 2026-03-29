terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

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

# Random suffix for unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Name        = local.name_prefix
    Environment = var.environment
    Component   = "storage"
  })
}

# Raw data bucket
resource "aws_s3_bucket" "raw" {
  bucket = "${local.name_prefix}-raw-${random_id.bucket_suffix.hex}"
  
  tags = merge(local.common_tags, {
    Purpose = "product-catalog-raw"
  })
}

resource "aws_s3_bucket_versioning" "raw" {
  count  = var.s3_versioning ? 1 : 0
  bucket = aws_s3_bucket.raw.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for raw bucket
resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "cleanup_uploads"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    transition {
      days          = var.s3_lifecycle_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.s3_lifecycle_days * 2
      storage_class = "GLACIER"
    }

    expiration {
      days = var.s3_lifecycle_days * 4
    }
  }
}

# Processed data bucket
resource "aws_s3_bucket" "processed" {
  bucket = "${local.name_prefix}-processed-${random_id.bucket_suffix.hex}"
  
  tags = merge(local.common_tags, {
    Purpose = "product-catalog-processed"
  })
}

resource "aws_s3_bucket_versioning" "processed" {
  count  = var.s3_versioning ? 1 : 0
  bucket = aws_s3_bucket.processed.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for processed bucket
resource "aws_s3_bucket_lifecycle_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    id     = "cleanup_enriched"
    status = "Enabled"

    filter {
      prefix = "enriched/"
    }

    transition {
      days          = var.s3_lifecycle_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.s3_lifecycle_days * 3
      storage_class = "GLACIER"
    }
  }
}

# Bucket for Lambda deployment packages
resource "aws_s3_bucket" "deployment" {
  bucket = "${local.name_prefix}-deployment-${random_id.bucket_suffix.hex}"
  
  tags = merge(local.common_tags, {
    Purpose = "lambda-deployment"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "deployment" {
  bucket = aws_s3_bucket.deployment.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "deployment" {
  bucket = aws_s3_bucket.deployment.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket for CloudWatch logs (optional)
resource "aws_s3_bucket" "logs" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = "${local.name_prefix}-logs-${random_id.bucket_suffix.hex}"
  
  tags = merge(local.common_tags, {
    Purpose = "cloudwatch-logs"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Outputs
output "raw_bucket_name" {
  description = "Name of the raw S3 bucket"
  value       = aws_s3_bucket.raw.bucket
}

output "raw_bucket_id" {
  description = "ID of the raw S3 bucket"
  value       = aws_s3_bucket.raw.id
}

output "raw_bucket_arn" {
  description = "ARN of the raw S3 bucket"
  value       = aws_s3_bucket.raw.arn
}

output "processed_bucket_name" {
  description = "Name of the processed S3 bucket"
  value       = aws_s3_bucket.processed.bucket
}

output "processed_bucket_id" {
  description = "ID of the processed S3 bucket"
  value       = aws_s3_bucket.processed.id
}

output "processed_bucket_arn" {
  description = "ARN of the processed S3 bucket"
  value       = aws_s3_bucket.processed.arn
}

output "deployment_bucket_name" {
  description = "Name of the deployment S3 bucket"
  value       = aws_s3_bucket.deployment.bucket
}

output "deployment_bucket_arn" {
  description = "ARN of the deployment S3 bucket"
  value       = aws_s3_bucket.deployment.arn
}

output "logs_bucket_name" {
  description = "Name of the logs S3 bucket"
  value       = var.environment == "prod" ? aws_s3_bucket.logs[0].bucket : null
}

output "logs_bucket_arn" {
  description = "ARN of the logs S3 bucket"
  value       = var.environment == "prod" ? aws_s3_bucket.logs[0].arn : null
}

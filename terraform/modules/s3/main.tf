variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

# Raw data bucket
resource "aws_s3_bucket" "raw" {
  bucket = "${var.project_name}-${var.environment}-raw-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-raw"
    Environment = var.environment
    Purpose     = "product-catalog-raw"
  }
}

resource "aws_s3_bucket_versioning" "raw" {
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

# Processed data bucket
resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_name}-${var.environment}-processed-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-processed"
    Environment = var.environment
    Purpose     = "product-catalog-processed"
  }
}

resource "aws_s3_bucket_versioning" "processed" {
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

# Random suffix for unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Outputs
output "raw_bucket_name" {
  value = aws_s3_bucket.raw.bucket
}

output "raw_bucket_id" {
  value = aws_s3_bucket.raw.id
}

output "raw_bucket_arn" {
  value = aws_s3_bucket.raw.arn
}

output "processed_bucket_name" {
  value = aws_s3_bucket.processed.bucket
}

output "processed_bucket_id" {
  value = aws_s3_bucket.processed.id
}

output "processed_bucket_arn" {
  value = aws_s3_bucket.processed.arn
}

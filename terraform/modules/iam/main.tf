variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "ingestion_lambda_arn" {
  description = "ARN of ingestion Lambda function"
  type        = string
}

variable "processing_lambda_arn" {
  description = "ARN of processing Lambda function"
  type        = string
}

variable "s3_raw_bucket_arn" {
  description = "ARN of raw S3 bucket"
  type        = string
}

variable "s3_processed_bucket_arn" {
  description = "ARN of processed S3 bucket"
  type        = string
}

# IAM role for ingestion Lambda
resource "aws_iam_role" "ingestion_lambda" {
  name = "${var.project_name}-${var.environment}-ingestion-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Ingestion Lambda policies
resource "aws_iam_role_policy" "ingestion_s3" {
  name = "${var.project_name}-${var.environment}-ingestion-s3"
  role = aws_iam_role.ingestion_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.s3_raw_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = var.s3_raw_bucket_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "ingestion_rds" {
  name = "${var.project_name}-${var.environment}-ingestion-rds"
  role = aws_iam_role.ingestion_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM role for processing Lambda
resource "aws_iam_role" "processing_lambda" {
  name = "${var.project_name}-${var.environment}-processing-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Processing Lambda policies
resource "aws_iam_role_policy" "processing_s3" {
  name = "${var.project_name}-${var.environment}-processing-s3"
  role = aws_iam_role.processing_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${var.s3_raw_bucket_arn}/*",
          "${var.s3_processed_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_raw_bucket_arn,
          var.s3_processed_bucket_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "processing_bedrock" {
  name = "${var.project_name}-${var.environment}-processing-bedrock"
  role = aws_iam_role.processing_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:ListFoundationModels"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "processing_rds" {
  name = "${var.project_name}-${var.environment}-processing-rds"
  role = aws_iam_role.processing_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = "*"
      }
    ]
  })
}

# Step Functions role
resource "aws_iam_role" "step_function" {
  name = "${var.project_name}-${var.environment}-step-function-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_function_lambda" {
  name = "${var.project_name}-${var.environment}-step-function-lambda"
  role = aws_iam_role.step_function.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.ingestion_lambda_arn,
          var.processing_lambda_arn
        ]
      }
    ]
  })
}

# Basic execution policies
resource "aws_iam_role_policy_attachment" "ingestion_basic" {
  role       = aws_iam_role.ingestion_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "processing_basic" {
  role       = aws_iam_role.processing_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "step_function_basic" {
  role       = aws_iam_role.step_function.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Outputs
output "step_function_role_arn" {
  value = aws_iam_role.step_function.arn
}

output "ingestion_lambda_role_arn" {
  value = aws_iam_role.ingestion_lambda.arn
}

output "processing_lambda_role_arn" {
  value = aws_iam_role.processing_lambda.arn
}

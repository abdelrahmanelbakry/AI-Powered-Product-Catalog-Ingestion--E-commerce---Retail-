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

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "lambda_functions" {
  description = "Lambda function information"
  type = object({
    ingestion = object({
      arn  = string
      name = string
    })
    processing = object({
      arn  = string
      name = string
    })
  })
}

variable "s3_buckets" {
  description = "S3 bucket information"
  type = object({
    raw = object({
      arn  = string
      name = string
    })
    processed = object({
      arn  = string
      name = string
    })
  })
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Name        = local.name_prefix
    Environment = var.environment
    Component   = "security"
  })
}

# IAM role for ingestion Lambda with least privilege
resource "aws_iam_role" "ingestion_lambda" {
  name = "${local.name_prefix}-ingestion-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Environment" = var.environment
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Purpose = "ingestion-lambda-role"
  })
}

# IAM role for processing Lambda with least privilege
resource "aws_iam_role" "processing_lambda" {
  name = "${local.name_prefix}-processing-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Environment" = var.environment
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Purpose = "processing-lambda-role"
  })
}

# Step Functions IAM role
resource "aws_iam_role" "step_function" {
  name = "${local.name_prefix}-step-function-role"

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

  tags = merge(local.common_tags, {
    Purpose = "step-function-role"
  })
}

# Ingestion Lambda policies - Least Privilege

# S3 access for ingestion (raw bucket only)
resource "aws_iam_role_policy" "ingestion_s3" {
  name = "${local.name_prefix}-ingestion-s3"
  role = aws_iam_role.ingestion_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${var.s3_buckets.raw.arn}/uploads/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${var.s3_buckets.raw.arn}/processed/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:DeleteObject"
        ]
        Resource = "${var.s3_buckets.raw.arn}/uploads/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = var.s3_buckets.raw.arn
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "uploads/*",
              "processed/*"
            ]
          }
        }
      }
    ]
  })
}

# RDS access for ingestion (specific database operations)
resource "aws_iam_role_policy" "ingestion_rds" {
  name = "${local.name_prefix}-ingestion-rds"
  role = aws_iam_role.ingestion_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = "arn:aws:rds-db:${var.aws_region}:${var.aws_account_id}:dbuser:*/${var.project_name}-${var.environment}-db/postgres"
      }
    ]
  })
}

# Processing Lambda policies - Least Privilege

# S3 access for processing (both buckets)
resource "aws_iam_role_policy" "processing_s3" {
  name = "${local.name_prefix}-processing-s3"
  role = aws_iam_role.processing_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "${var.s3_buckets.raw.arn}/*",
          "${var.s3_buckets.processed.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${var.s3_buckets.processed.arn}/enriched/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_buckets.raw.arn,
          var.s3_buckets.processed.arn
        ]
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "*"
            ]
          }
        }
      }
    ]
  })
}

# Bedrock access for processing (specific model only)
resource "aws_iam_role_policy" "processing_bedrock" {
  name = "${local.name_prefix}-processing-bedrock"
  role = aws_iam_role.processing_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-v2"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:ListFoundationModels"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  })
}

# RDS access for processing (specific database operations)
resource "aws_iam_role_policy" "processing_rds" {
  name = "${local.name_prefix}-processing-rds"
  role = aws_iam_role.processing_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = "arn:aws:rds-db:${var.aws_region}:${var.aws_account_id}:dbuser:*/${var.project_name}-${var.environment}-db/postgres"
      }
    ]
  })
}

# Step Functions policies - Least Privilege

# IAM policy for Step Functions to invoke Lambda functions
resource "aws_iam_policy" "step_function_lambda_policy" {
  name        = "${var.project_name}-${var.environment}-step-function-lambda-policy"
  description = "Policy for Step Functions to invoke Lambda functions"

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
          var.processing_lambda_arn,
          var.chatbot_lambda_arn
        ]
          }
        }
      }
    ]
  })
}

# CloudWatch Logs access for Step Functions
resource "aws_iam_role_policy" "step_function_logs" {
  name = "${local.name_prefix}-step-function-logs"
  role = aws_iam_role.step_function.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/states/*"
      }
    ]
  })
}

# X-Ray access for tracing (optional)
resource "aws_iam_role_policy" "lambda_xray" {
  count = var.environment == "prod" ? 2 : 0
  name  = "${local.name_prefix}-lambda-xray-${count.index == 0 ? "ingestion" : "processing"}"
  role  = count.index == 0 ? aws_iam_role.ingestion_lambda.id : aws_iam_role.processing_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = "*"
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

# VPC access policies (if Lambda needs VPC access)
resource "aws_iam_role_policy" "ingestion_vpc" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${local.name_prefix}-ingestion-vpc"
  role  = aws_iam_role.ingestion_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "processing_vpc" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${local.name_prefix}-processing-vpc"
  role  = aws_iam_role.processing_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM policy for CloudWatch metrics
resource "aws_iam_role_policy" "lambda_metrics" {
  count = var.environment == "prod" ? 2 : 0
  name  = "${local.name_prefix}-lambda-metrics-${count.index == 0 ? "ingestion" : "processing"}"
  role  = count.index == 0 ? aws_iam_role.ingestion_lambda.id : aws_iam_role.processing_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = [
              "AWS/Lambda",
              "${var.project_name}-${var.environment}"
            ]
          }
        }
      }
    ]
  })
}

# Security Group for Lambda (if VPC enabled)
resource "aws_security_group" "lambda" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${local.name_prefix}-lambda-sg"
  
  tags = merge(local.common_tags, {
    Purpose = "lambda-security-group"
  })
}

# Outputs
output "ingestion_lambda_role_arn" {
  description = "ARN of the ingestion Lambda role"
  value       = aws_iam_role.ingestion_lambda.arn
}

output "processing_lambda_arn" {
  description = "ARN of the processing Lambda function"
  type        = string
}

variable "chatbot_lambda_arn" {
  description = "ARN of the chatbot Lambda function"
  type        = string
}

output "processing_lambda_role_arn" {
  description = "ARN of the processing Lambda role"
  value       = aws_iam_role.processing_lambda.arn
}

output "chatbot_lambda_role_arn" {
  description = "ARN of the chatbot Lambda role"
  value       = aws_iam_role.chatbot_lambda.arn
}

output "step_function_role_arn" {
  description = "ARN of the Step Functions role"
  value       = aws_iam_role.step_function.arn
}

output "ingestion_lambda_role_name" {
  description = "Name of the ingestion Lambda role"
  value       = aws_iam_role.ingestion_lambda.name
}

output "processing_lambda_role_name" {
  description = "Name of the processing Lambda role"
  value       = aws_iam_role.processing_lambda.name
}

output "step_function_role_name" {
  description = "Name of the Step Functions role"
  value       = aws_iam_role.step_function.name
}

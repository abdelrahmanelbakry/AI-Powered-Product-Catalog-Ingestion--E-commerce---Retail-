variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "function_name" {
  description = "Lambda function name suffix"
  type        = string
}

variable "handler" {
  description = "Lambda handler"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket containing deployment package"
  type        = string
}

variable "s3_key" {
  description = "S3 key for deployment package"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for Lambda"
  type        = map(string)
  default     = {}
}

# IAM role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-${var.function_name}-role"

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

  tags = {
    Name        = "${var.project_name}-${var.environment}-${var.function_name}-role"
    Environment = var.environment
  }
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Logs policy
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${var.project_name}-${var.environment}-${var.function_name}-logs"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "main" {
  function_name = "${var.project_name}-${var.environment}-${var.function_name}"
  handler       = var.handler
  runtime       = var.runtime
  role          = aws_iam_role.lambda.arn

  s3_bucket         = var.s3_bucket
  s3_key            = var.s3_key
  source_code_hash  = data.archive_file.lambda_deployment.output_base64sha256

  timeout = 300  # 5 minutes
  memory_size = 512

  environment {
    variables = var.environment_variables
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.cloudwatch_logs
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-${var.function_name}"
    Environment = var.environment
  }
}

# Deployment package
data "archive_file" "lambda_deployment" {
  type        = "zip"
  source_dir  = "${path.root}/../../lambda/${var.function_name}"
  output_path = "${path.root}/../../lambda/${var.function_name}.zip"
}

# Outputs
output "lambda_name" {
  value = aws_lambda_function.main.function_name
}

output "lambda_arn" {
  value = aws_lambda_function.main.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

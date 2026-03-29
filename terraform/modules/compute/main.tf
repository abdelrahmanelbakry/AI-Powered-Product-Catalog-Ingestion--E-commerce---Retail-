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

variable "lambda_functions" {
  description = "Lambda function configurations"
  type = object({
    ingestion = object({
      handler               = string
      runtime               = string
      timeout               = number
      memory_size           = number
      environment_variables = map(string)
      reserved_concurrency  = number
    })
    processing = object({
      handler               = string
      runtime               = string
      timeout               = number
      memory_size           = number
      environment_variables = map(string)
      reserved_concurrency  = number
    })
    chatbot = object({
      handler               = string
      runtime               = string
      timeout               = number
      memory_size           = number
      environment_variables = map(string)
      reserved_concurrency  = number
    })
  })
  default = {
    ingestion = {
      handler               = "index.handler"
      runtime               = "nodejs14.x"
      timeout               = 300
      memory_size           = 512
      environment_variables = {}
      reserved_concurrency  = 0
    }
    processing = {
      handler               = "index.handler"
      runtime               = "nodejs14.x"
      timeout               = 900
      memory_size           = 1024
      environment_variables = {}
      reserved_concurrency  = 0
    }
    chatbot = {
      handler               = "index.handler"
      runtime               = "nodejs14.x"
      timeout               = 300
      memory_size           = 512
      environment_variables = {}
      reserved_concurrency  = 10
    }
  }
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
    Component   = "compute"
  })
}

# IAM role for ingestion Lambda
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
      }
    ]
  })

  tags = merge(local.common_tags, {
    Purpose = "ingestion-lambda-role"
  })
}

# IAM role for processing Lambda
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
      }
    ]
  })

  tags = local.common_tags
}

# IAM role for ChatBot Lambda
resource "aws_iam_role" "chatbot_lambda" {
  name = "${local.name_prefix}-chatbot-lambda-role"
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

  tags = local.common_tags
}

# Basic Lambda execution policies
resource "aws_iam_role_policy_attachment" "ingestion_basic" {
  role       = aws_iam_role.ingestion_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "processing_basic" {
  role       = aws_iam_role.processing_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "chatbot_basic" {
  role       = aws_iam_role.chatbot_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Logs policy
resource "aws_iam_role_policy" "ingestion_logs" {
  name = "${local.name_prefix}-ingestion-logs"
  role = aws_iam_role.ingestion_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:FilterLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "processing_logs" {
  name = "${local.name_prefix}-processing-logs"
  role = aws_iam_role.processing_lambda.id

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

resource "aws_iam_role_policy" "chatbot_logs" {
  name = "${local.name_prefix}-chatbot-logs"
  role = aws_iam_role.chatbot_lambda.id

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

# Ingestion Lambda function
resource "aws_lambda_function" "ingestion" {
  function_name = "${local.name_prefix}-ingestion"
  handler       = var.ingestion_config.handler
  runtime       = var.ingestion_config.runtime
  role          = aws_iam_role.ingestion_lambda.arn

  timeout     = var.ingestion_config.timeout
  memory_size = var.ingestion_config.memory_size

  environment {
    variables = var.ingestion_config.environment_variables
  }

  # Package information - will be updated during deployment
  s3_bucket         = "placeholder-bucket"
  s3_key            = "placeholder-key"
  source_code_hash  = filebase64sha256("${path.module}/placeholder")

  depends_on = [
    aws_iam_role_policy_attachment.ingestion_basic,
    aws_iam_role_policy.ingestion_logs
  ]

  tags = merge(local.common_tags, {
    Purpose = "file-ingestion"
  })

  depends_on = [
    var.deployment_bucket != null ? data.aws_s3_object.ingestion_zip : null
  ]
}

# S3 object references for Lambda code
data "aws_s3_object" "processing_zip" {
  count  = var.deployment_bucket != null ? 1 : 0
  bucket = var.deployment_bucket
  key    = "lambda/processing.zip"
}

data "aws_s3_object" "chatbot_zip" {
  count  = var.deployment_bucket != null ? 1 : 0
  bucket = var.deployment_bucket
  key    = "lambda/chatbot.zip"
}

# Processing Lambda function
resource "aws_lambda_function" "processing" {
  filename         = "processing.zip"
  source_code_hash = var.deployment_bucket != null ? data.aws_s3_object.processing_zip.body : null
  function_name    = "${local.name_prefix}-processing"
  role             = aws_iam_role.processing_lambda.arn
  handler          = var.lambda_functions.processing.handler
  runtime          = var.lambda_functions.processing.runtime
  timeout          = var.lambda_functions.processing.timeout
  memory_size      = var.lambda_functions.processing.memory_size

  environment {
    variables = merge(var.lambda_functions.processing.environment_variables, {
      DB_HOST = var.db_host
      DB_NAME = var.db_name
      DB_USER = var.db_user
      DB_PASSWORD = var.db_password
      PROCESSED_BUCKET = var.processed_bucket
      BEDROCK_REGION = var.bedrock_region
      BEDROCK_MODEL = var.bedrock_model
    })
  }

  reserved_concurrent_executions = var.environment == "prod" ? var.lambda_functions.processing.reserved_concurrency : 0

  tags = merge(local.common_tags, {
    Purpose = "data-processing"
  })

  depends_on = [
    var.deployment_bucket != null ? data.aws_s3_object.processing_zip : null
  ]
}

# Lambda function for ChatBot
resource "aws_lambda_function" "chatbot" {
  filename         = "chatbot.zip"
  source_code_hash = var.deployment_bucket != null ? data.aws_s3_object.chatbot_zip.body : null
  function_name    = "${local.name_prefix}-chatbot"
  role             = aws_iam_role.chatbot_lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = var.lambda_functions.chatbot.timeout
  memory_size      = var.lambda_functions.chatbot.memory_size

  environment {
    variables = merge(var.lambda_functions.chatbot.environment_variables, {
      DB_HOST = var.db_host
      DB_NAME = var.db_name
      DB_USER = var.db_user
      DB_PASSWORD = var.db_password
      PROCESSED_BUCKET = var.processed_bucket
      BEDROCK_REGION = var.bedrock_region
      BEDROCK_MODEL = var.bedrock_model
    })
  }

  reserved_concurrent_executions = var.environment == "prod" ? var.lambda_functions.chatbot.reserved_concurrency : 0

  tags = merge(local.common_tags, {
    Purpose = "chatbot"
  })

  depends_on = [
    var.deployment_bucket != null ? data.aws_s3_object.chatbot_zip : null
  ]
}

# Lambda reserved concurrency (optional)
resource "aws_lambda_reserved_concurrent_executions" "ingestion" {
  count                     = var.environment == "prod" ? 1 : 0
  function_name             = aws_lambda_function.ingestion.function_name
  reserved_concurrent_executions = 10
}

resource "aws_lambda_reserved_concurrent_executions" "processing" {
  count                     = var.environment == "prod" ? 1 : 0
  function_name             = aws_lambda_function.processing.function_name
  reserved_concurrent_executions = 5
}

resource "aws_lambda_reserved_concurrent_executions" "chatbot" {
  count                     = var.environment == "prod" ? 1 : 0
  function_name             = aws_lambda_function.chatbot.function_name
  reserved_concurrent_executions = 10
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "ingestion_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ingestion.function_name}"
  retention_in_days = var.environment == "prod" ? 30 : 14

  tags = merge(local.common_tags, {
    Purpose = "ingestion-logs"
  })
}

resource "aws_cloudwatch_log_group" "processing_logs" {
  name              = "/aws/lambda/${aws_lambda_function.processing.function_name}"
  retention_in_days = var.environment == "prod" ? 30 : 14

  tags = merge(local.common_tags, {
    Purpose = "processing-logs"
  })
}

resource "aws_cloudwatch_log_group" "chatbot_logs" {
  name              = "/aws/lambda/${aws_lambda_function.chatbot.function_name}"
  retention_in_days = var.environment == "prod" ? 30 : 14

  tags = merge(local.common_tags, {
    Purpose = "chatbot-logs"
  })
}

# Lambda function aliases for versioning
resource "aws_lambda_alias" "ingestion_alias" {
  count             = var.environment == "prod" ? 1 : 0
  function_name    = aws_lambda_function.ingestion.function_name
  function_version = aws_lambda_function.ingestion.version
  name             = "current"
}

resource "aws_lambda_alias" "processing_alias" {
  count             = var.environment == "prod" ? 1 : 0
  function_name    = aws_lambda_function.processing.function_name
  function_version = aws_lambda_function.processing.version
  name             = "current"
}

resource "aws_lambda_alias" "chatbot_alias" {
  count             = var.environment == "prod" ? 1 : 0
  function_name    = aws_lambda_function.chatbot.function_name
  function_version = aws_lambda_function.chatbot.version
  name             = "current"
}

# Lambda event source mappings (for future SQS integration)
resource "aws_lambda_event_source_mapping" "ingestion_sqs" {
  count           = 0 # Set to 1 when SQS is implemented
  event_source_arn = "arn:aws:sqs:us-east-1:123456789012:my-queue"
  function_name   = aws_lambda_function.ingestion.arn
  batch_size      = 10
  enabled         = true
}

# Placeholder file for source_code_hash
resource "local_file" "placeholder" {
  content  = "placeholder"
  filename = "${path.module}/placeholder"
}

# Outputs
output "ingestion_lambda_name" {
  description = "Name of the ingestion Lambda function"
  value       = aws_lambda_function.ingestion.function_name
}

output "ingestion_lambda_arn" {
  description = "ARN of the ingestion Lambda function"
  value       = aws_lambda_function.ingestion.arn
}

output "ingestion_lambda_role_arn" {
  description = "ARN of the ingestion Lambda role"
  value       = aws_iam_role.ingestion_lambda.arn
}

output "ingestion_lambda_alias_arn" {
  description = "ARN of the ingestion Lambda current alias"
  value       = aws_lambda_alias.ingestion_current.arn
}

output "processing_lambda_name" {
  description = "Name of the processing Lambda function"
  value       = aws_lambda_function.processing.function_name
}

output "processing_lambda_arn" {
  description = "ARN of the processing Lambda function"
  value       = aws_lambda_function.processing.arn
}

output "processing_lambda_role_arn" {
  description = "ARN of the processing Lambda IAM role"
  type        = string
  value       = aws_iam_role.processing_lambda.arn
}

variable "chatbot_lambda_role_arn" {
  description = "ARN of the chatbot Lambda IAM role"
  type        = string
}

variable "deployment_bucket" {
  description = "S3 bucket for Lambda deployment packages"
  type        = string
  default     = null
}

output "processing_lambda_alias_arn" {
  description = "ARN of the processing Lambda current alias"
  value       = aws_lambda_alias.processing_current.arn
}

output "chatbot_lambda_name" {
  description = "Name of the chatbot Lambda function"
  value       = aws_lambda_function.chatbot.function_name
}

output "chatbot_lambda_arn" {
  description = "ARN of the chatbot Lambda function"
  value       = aws_lambda_function.chatbot.arn
}

output "chatbot_lambda_invoke_arn" {
  description = "Invoke ARN of the chatbot Lambda function"
  value       = aws_lambda_function.chatbot.invoke_arn
}

output "chatbot_lambda_role_arn" {
  description = "ARN of the chatbot Lambda IAM role"
  value       = aws_iam_role.chatbot_lambda.arn
}

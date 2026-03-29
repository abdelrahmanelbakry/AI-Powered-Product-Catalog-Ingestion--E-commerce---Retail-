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
  description = "Lambda function names"
  type = object({
    ingestion  = string
    processing = string
  })
}

variable "step_function_name" {
  description = "Step Functions state machine name"
  type        = string
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

variable "log_retention_days" {
  description = "CloudWatch log retention period (days)"
  type        = number
  default     = 14
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
    Component   = "monitoring"
  })
}

# SNS Topic for alarm notifications
resource "aws_sns_topic" "alarms" {
  count  = var.enable_cloudwatch_alarms && var.alarm_email != "" ? 1 : 0
  name   = "${local.name_prefix}-alarms"

  tags = merge(local.common_tags, {
    Purpose = "alarm-notifications"
  })
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.enable_cloudwatch_alarms && var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Lambda Function Metrics and Alarms

# Ingestion Lambda Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "ingestion_errors" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${local.name_prefix}-ingestion-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors the number of errors in the ingestion Lambda function"
  alarm_actions       = var.enable_cloudwatch_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    FunctionName = var.lambda_functions.ingestion
  }

  tags = merge(local.common_tags, {
    Purpose = "ingestion-error-alarm"
  })
}

# Ingestion Lambda Duration Alarm
resource "aws_cloudwatch_metric_alarm" "ingestion_duration" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${local.name_prefix}-ingestion-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "240000"  # 4 minutes in milliseconds
  alarm_description   = "This metric monitors the duration of the ingestion Lambda function"
  alarm_actions       = var.enable_cloudwatch_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    FunctionName = var.lambda_functions.ingestion
  }

  tags = merge(local.common_tags, {
    Purpose = "ingestion-duration-alarm"
  })
}

# Processing Lambda Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "processing_errors" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${local.name_prefix}-processing-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "This metric monitors the number of errors in the processing Lambda function"
  alarm_actions       = var.enable_cloudwatch_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    FunctionName = var.lambda_functions.processing
  }

  tags = merge(local.common_tags, {
    Purpose = "processing-error-alarm"
  })
}

# Processing Lambda Duration Alarm
resource "aws_cloudwatch_metric_alarm" "processing_duration" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${local.name_prefix}-processing-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "270000"  # 4.5 minutes in milliseconds
  alarm_description   = "This metric monitors the duration of the processing Lambda function"
  alarm_actions       = var.enable_cloudwatch_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    FunctionName = var.lambda_functions.processing
  }

  tags = merge(local.common_tags, {
    Purpose = "processing-duration-alarm"
  })
}

# Step Functions Execution Failures Alarm
resource "aws_cloudwatch_metric_alarm" "step_function_failures" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${local.name_prefix}-step-function-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ExecutionFailed"
  namespace           = "AWS/States"
  period              = "300"
  statistic           = "Sum"
  threshold           = "2"
  alarm_description   = "This metric monitors Step Functions execution failures"
  alarm_actions       = var.enable_cloudwatch_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  dimensions = {
    StateMachineArn = "arn:aws:states:*:*:stateMachine:${var.step_function_name}"
  }

  tags = merge(local.common_tags, {
    Purpose = "step-function-failure-alarm"
  })
}

# Custom Metrics Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_functions.ingestion],
            [".", "Errors", "FunctionName", var.lambda_functions.ingestion],
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_functions.processing],
            [".", "Errors", "FunctionName", var.lambda_functions.processing]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "Lambda Function Invocations and Errors"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_functions.ingestion],
            [".", "Duration", "FunctionName", var.lambda_functions.processing]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "Lambda Function Duration"
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/States", "ExecutionsStarted", "StateMachineArn", "arn:aws:states:*:*:stateMachine:${var.step_function_name}"],
            [".", "ExecutionsSucceeded", ".", "."],
            [".", "ExecutionsFailed", ".", "."],
            [".", "ExecutionTime", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "Step Functions Executions"
          view   = "timeSeries"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '/aws/lambda/${var.lambda_functions.ingestion}'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| limit 100"
          region  = "us-east-1"
          title   = "Ingestion Lambda Error Logs"
          view    = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 24
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '/aws/lambda/${var.lambda_functions.processing}'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| limit 100"
          region  = "us-east-1"
          title   = "Processing Lambda Error Logs"
          view    = "table"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Purpose = "main-dashboard"
  })
}

# Custom CloudWatch Metrics

# Records Processed Metric
resource "aws_cloudwatch_log_metric_filter" "records_processed" {
  name           = "${local.name_prefix}-records-processed"
  log_group_name = "/aws/lambda/${var.lambda_functions.processing}"
  pattern        = "[timestamp, request_id, message, level, ..., processed_count = *, ...]"

  metric_transformation {
    name      = "RecordsProcessed"
    namespace = "${var.project_name}-${var.environment}"
    value     = "$processed_count"
  }
}

# Processing Success Rate Metric
resource "aws_cloudwatch_log_metric_filter" "processing_success_rate" {
  name           = "${local.name_prefix}-processing-success-rate"
  log_group_name = "/aws/lambda/${var.lambda_functions.processing}"
  pattern        = "[timestamp, request_id, message, level, ..., processed_count = *, failed_count = *, ...]"

  metric_transformation {
    name      = "ProcessingSuccessRate"
    namespace = "${var.project_name}-${var.environment}"
    value     = "$processed_count / ($processed_count + $failed_count) * 100"
  }
}

# Bedrock API Calls Metric
resource "aws_cloudwatch_log_metric_filter" "bedrock_calls" {
  name           = "${local.name_prefix}-bedrock-calls"
  log_group_name = "/aws/lambda/${var.lambda_functions.processing}"
  pattern        = "[timestamp, request_id, message, level, ..., bedrock_api_call = *, ...]"

  metric_transformation {
    name      = "BedrockAPICalls"
    namespace = "${var.project_name}-${var.environment}"
    value     = "1"
  }
}

# Custom Metric Alarms
resource "aws_cloudwatch_metric_alarm" "low_success_rate" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${local.name_prefix}-low-success-rate"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ProcessingSuccessRate"
  namespace           = "${var.project_name}-${var.environment}"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors the processing success rate"
  alarm_actions       = var.enable_cloudwatch_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = merge(local.common_tags, {
    Purpose = "low-success-rate-alarm"
  })
}

# Log Insights Queries
resource "aws_cloudwatch_query_definition" "error_analysis" {
  name = "${local.name_prefix}-error-analysis"

  log_group_names = [
    "/aws/lambda/${var.lambda_functions.ingestion}",
    "/aws/lambda/${var.lambda_functions.processing}"
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /ERROR/
    | sort @timestamp desc
    | limit 100
  EOT
}

resource "aws_cloudwatch_query_definition" "performance_analysis" {
  name = "${local.name_prefix}-performance-analysis"

  log_group_names = [
    "/aws/lambda/${var.lambda_functions.ingestion}",
    "/aws/lambda/${var.lambda_functions.processing}"
  ]

  query_string = <<-EOT
    fields @timestamp, @message, @logStream
    | filter @message like /processed_count/
    | parse @message "processed_count: *" as processed_count
    | stats sum(processed_count) as total_processed by bin(1h)
    | sort @timestamp desc
  EOT
}

# Outputs
output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = var.enable_cloudwatch_alarms && var.alarm_email != "" ? aws_sns_topic.alarms[0].arn : null
}

output "alarm_names" {
  description = "List of CloudWatch alarm names"
  value = var.enable_cloudwatch_alarms ? [
    aws_cloudwatch_metric_alarm.ingestion_errors[0].alarm_name,
    aws_cloudwatch_metric_alarm.ingestion_duration[0].alarm_name,
    aws_cloudwatch_metric_alarm.processing_errors[0].alarm_name,
    aws_cloudwatch_metric_alarm.processing_duration[0].alarm_name,
    aws_cloudwatch_metric_alarm.step_function_failures[0].alarm_name,
    aws_cloudwatch_metric_alarm.low_success_rate[0].alarm_name
  ] : []
}

output "chatbot_api_log_group_arn" {
  description = "ARN of the ChatBot API log group"
  value = aws_cloudwatch_log_group.chatbot_api_logs.arn
}

# Log group for ChatBot API
resource "aws_cloudwatch_log_group" "chatbot_api_logs" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}-chatbot"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Purpose = "chatbot-api-logs"
  })
}

# Data source for AWS region
data "aws_region" "current" {}

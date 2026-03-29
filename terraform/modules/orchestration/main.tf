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
  description = "Lambda function ARNs"
  type = object({
    ingestion  = string
    processing = string
  })
}

variable "step_function_role_arn" {
  description = "ARN of the Step Functions IAM role"
  type        = string
}

variable "step_function_timeout" {
  description = "Step Functions execution timeout (seconds)"
  type        = number
  default     = 3600
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
    Component   = "orchestration"
  })
}

# Main product processing workflow
resource "aws_sfn_state_machine" "product_processing" {
  name     = "${local.name_prefix}-product-processing"
  role_arn = var.step_function_role_arn
  timeout  = var.step_function_timeout

  definition = jsonencode({
    Comment = "Enhanced Product Catalog Processing Workflow"
    StartAt = "CheckForNewFiles"
    
    States = {
      CheckForNewFiles = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_functions.processing
          Payload = {
            "action" = "check_unprocessed_records"
          }
        }
        ResultPath = "$.check_result"
        Next = "HasRecordsToProcess"
        Retry = [
          {
            ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
            IntervalSeconds = 2
            MaxAttempts = 3
            BackoffRate = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "CheckError"
            ResultPath = "$.error_info"
          }
        ]
      }
      
      HasRecordsToProcess = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.check_result.Payload.processed_count"
            NumericGreaterThan = 0
            Next = "ProcessRecords"
          }
        ]
        Default = "NoRecordsToProcess"
      }
      
      ProcessRecords = {
        Type = "Parallel"
        Branches = [
          {
            StartAt = "ProcessBatch1"
            States = {
              ProcessBatch1 = {
                Type = "Task"
                Resource = "arn:aws:states:::lambda:invoke"
                Parameters = {
                  FunctionName = var.lambda_functions.processing
                  Payload = {
                    "action" = "process_batch"
                    "batch_size" = 10
                    "batch_id" = 1
                  }
                }
                ResultPath = "$.batch1_result"
                End = true
                Retry = [
                  {
                    ErrorEquals = ["Bedrock.ThrottlingException", "Bedrock.ServiceQuotaExceededException"]
                    IntervalSeconds = 5
                    MaxAttempts = 5
                    BackoffRate = 2.0
                  }
                ]
                Catch = [
                  {
                    ErrorEquals = ["States.ALL"]
                    Next = "BatchError"
                    ResultPath = "$.batch1_error"
                  }
                ]
              }
              
              BatchError = {
                Type = "Pass"
                Result = {
                  "error" = "Batch processing failed"
                  "batch_id" = 1
                }
                End = true
              }
            }
          },
          {
            StartAt = "ProcessBatch2"
            States = {
              ProcessBatch2 = {
                Type = "Task"
                Resource = "arn:aws:states:::lambda:invoke"
                Parameters = {
                  FunctionName = var.lambda_functions.processing
                  Payload = {
                    "action" = "process_batch"
                    "batch_size" = 10
                    "batch_id" = 2
                  }
                }
                ResultPath = "$.batch2_result"
                End = true
                Retry = [
                  {
                    ErrorEquals = ["Bedrock.ThrottlingException", "Bedrock.ServiceQuotaExceededException"]
                    IntervalSeconds = 5
                    MaxAttempts = 5
                    BackoffRate = 2.0
                  }
                ]
                Catch = [
                  {
                    ErrorEquals = ["States.ALL"]
                    Next = "BatchError"
                    ResultPath = "$.batch2_error"
                  }
                ]
              }
              
              BatchError = {
                Type = "Pass"
                Result = {
                  "error" = "Batch processing failed"
                  "batch_id" = 2
                }
                End = true
              }
            }
          }
        ]
        ResultPath = "$.parallel_result"
        Next = "AggregateResults"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "ParallelError"
            ResultPath = "$.parallel_error"
          }
        ]
      }
      
      AggregateResults = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_functions.processing
          Payload = {
            "action" = "aggregate_results"
            "batch_results" = "$.parallel_result"
          }
        }
        ResultPath = "$.aggregate_result"
        Next = "UpdateProcessingStatus"
        Retry = [
          {
            ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts = 3
          }
        ]
      }
      
      UpdateProcessingStatus = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_functions.processing
          Payload = {
            "action" = "update_status"
            "status" = "completed"
            "summary" = "$.aggregate_result.Payload"
          }
        }
        ResultPath = "$.status_result"
        Next = "Success"
        Retry = [
          {
            ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts = 3
          }
        ]
      }
      
      NoRecordsToProcess = {
        Type = "Succeed"
        Result = {
          "message" = "No records to process"
          "timestamp" = "$$.State.EnteredTime"
        }
      }
      
      CheckError = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_functions.processing
          Payload = {
            "action" = "log_error"
            "error" = "$.error_info"
          }
        }
        ResultPath = "$.error_logged"
        Next = "Failure"
      }
      
      ParallelError = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_functions.processing
          Payload = {
            "action" = "log_error"
            "error" = "$.parallel_error"
          }
        }
        ResultPath = "$.error_logged"
        Next = "Failure"
      }
      
      Success = {
        Type = "Succeed"
        Result = {
          "message" = "Product processing completed successfully"
          "timestamp" = "$$.State.EnteredTime"
          "results" = "$.aggregate_result.Payload"
        }
      }
      
      Failure = {
        Type = "Fail"
        Cause = "Product processing failed"
        Error = "ProcessingError"
      }
    }
  })

  tags = merge(local.common_tags, {
    Purpose = "main-processing-workflow"
  })
}

# Scheduled Step Functions execution
resource "aws_cloudwatch_event_rule" "step_function_schedule" {
  name                = "${local.name_prefix}-processing-schedule"
  description         = "Trigger product processing workflow every 5 minutes"
  schedule_expression = "rate(5 minutes)"

  tags = merge(local.common_tags, {
    Purpose = "step-function-schedule"
  })
}

resource "aws_cloudwatch_event_target" "step_function_target" {
  rule      = aws_cloudwatch_event_rule.step_function_schedule.name
  target_id = "ProductProcessingTarget"
  arn       = aws_sfn_state_machine.product_processing.arn
  role_arn  = aws_iam_role.event_bridge_role.arn
}

# Event Bridge IAM role
resource "aws_iam_role" "event_bridge_role" {
  name = "${local.name_prefix}-event-bridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Purpose = "event-bridge-role"
  })
}

resource "aws_iam_role_policy" "event_bridge_policy" {
  name = "${local.name_prefix}-event-bridge-policy"
  role = aws_iam_role.event_bridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = aws_sfn_state_machine.product_processing.arn
      }
    ]
  })
}

# Manual trigger Step Function
resource "aws_sfn_state_machine" "manual_processing" {
  name     = "${local.name_prefix}-manual-processing"
  role_arn = var.step_function_role_arn
  timeout  = 300

  definition = jsonencode({
    Comment = "Manual product processing trigger"
    StartAt = "ManualProcessTrigger"
    
    States = {
      ManualProcessTrigger = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_functions.processing
          Payload = {
            "action" = "manual_process"
            "triggered_by" = "$$.State.Name"
            "timestamp" = "$$.State.EnteredTime"
          }
        }
        ResultPath = "$.manual_result"
        Next = "ManualComplete"
        Retry = [
          {
            ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts = 3
          }
        ]
      }
      
      ManualComplete = {
        Type = "Succeed"
        Result = {
          "message" = "Manual processing completed"
          "timestamp" = "$$.State.EnteredTime"
          "results" = "$.manual_result.Payload"
        }
      }
    }
  })

  tags = merge(local.common_tags, {
    Purpose = "manual-processing-workflow"
  })
}

# Error handling and retry workflow
resource "aws_sfn_state_machine" "error_recovery" {
  name     = "${local.name_prefix}-error-recovery"
  role_arn = var.step_function_role_arn
  timeout  = 600

  definition = jsonencode({
    Comment = "Error recovery workflow for failed records"
    StartAt = "IdentifyFailedRecords"
    
    States = {
      IdentifyFailedRecords = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_functions.processing
          Payload = {
            "action" = "identify_failed_records"
          }
        }
        ResultPath = "$.failed_records"
        Next = "HasFailedRecords"
        Retry = [
          {
            ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts = 3
          }
        ]
      }
      
      HasFailedRecords = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.failed_records.Payload.failed_count"
            NumericGreaterThan = 0
            Next = "RetryFailedRecords"
          }
        ]
        Default = "NoFailedRecords"
      }
      
      RetryFailedRecords = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_functions.processing
          Payload = {
            "action" = "retry_failed_records"
            "failed_records" = "$.failed_records.Payload.failed_records"
            "retry_count" = 1
          }
        }
        ResultPath = "$.retry_result"
        Next = "CheckRetrySuccess"
        Retry = [
          {
            ErrorEquals = ["Bedrock.ThrottlingException"]
            IntervalSeconds = 10
            MaxAttempts = 3
            BackoffRate = 2.0
          }
        ]
      }
      
      CheckRetrySuccess = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.retry_result.Payload.success_count"
            NumericGreaterThan = 0
            Next = "LogRetrySuccess"
          }
        ]
        Default = "RetryFailed"
      }
      
      LogRetrySuccess = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_functions.processing
          Payload = {
            "action" = "log_retry_success"
            "results" = "$.retry_result.Payload"
          }
        }
        ResultPath = "$.log_result"
        Next = "RecoveryComplete"
      }
      
      RetryFailed = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.lambda_functions.processing
          Payload = {
            "action" = "escalate_failed_records"
            "failed_records" = "$.failed_records.Payload.failed_records"
          }
        }
        ResultPath = "$.escalate_result"
        Next = "RecoveryComplete"
      }
      
      NoFailedRecords = {
        Type = "Succeed"
        Result = {
          "message" = "No failed records to recover"
          "timestamp" = "$$.State.EnteredTime"
        }
      }
      
      RecoveryComplete = {
        Type = "Succeed"
        Result = {
          "message" = "Error recovery completed"
          "timestamp" = "$$.State.EnteredTime"
          "results" = "$.retry_result.Payload"
        }
      }
    }
  })

  tags = merge(local.common_tags, {
    Purpose = "error-recovery-workflow"
  })
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_function_logs" {
  name              = "/aws/states/${aws_sfn_state_machine.product_processing.name}"
  retention_in_days = var.environment == "prod" ? 30 : 14

  tags = merge(local.common_tags, {
    Purpose = "step-function-logs"
  })
}

# Outputs
output "step_function_name" {
  description = "Name of the main Step Functions state machine"
  value       = aws_sfn_state_machine.product_processing.name
}

output "step_function_arn" {
  description = "ARN of the main Step Functions state machine"
  value       = aws_sfn_state_machine.product_processing.arn
}

output "manual_step_function_name" {
  description = "Name of the manual Step Functions state machine"
  value       = aws_sfn_state_machine.manual_processing.name
}

output "manual_step_function_arn" {
  description = "ARN of the manual Step Functions state machine"
  value       = aws_sfn_state_machine.manual_processing.arn
}

output "error_recovery_step_function_name" {
  description = "Name of the error recovery Step Functions state machine"
  value       = aws_sfn_state_machine.error_recovery.name
}

output "error_recovery_step_function_arn" {
  description = "ARN of the error recovery Step Functions state machine"
  value       = aws_sfn_state_machine.error_recovery.arn
}

output "event_schedule_name" {
  description = "Name of the CloudWatch event schedule"
  value       = aws_cloudwatch_event_rule.step_function_schedule.name
}

output "event_schedule_arn" {
  description = "ARN of the CloudWatch event schedule"
  value       = aws_cloudwatch_event_rule.step_function_schedule.arn
}

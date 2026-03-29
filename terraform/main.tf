terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources for existing resources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Core Infrastructure Module
module "core_infrastructure" {
  source = "./modules/core-infrastructure"
  
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  
  tags = var.tags
}

# Storage Module
module "storage" {
  source = "./modules/storage"
  
  project_name = var.project_name
  environment  = var.environment
  
  tags = var.tags
}

# Database Module
module "database" {
  source = "./modules/database"
  
  project_name      = var.project_name
  environment       = var.environment
  db_instance_class = var.db_instance_class
  db_name          = var.db_name
  db_username      = var.db_username
  db_password      = var.db_password
  
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  
  tags = var.tags
}

# Compute Module (Lambda Functions)
module "compute" {
  source = "./modules/compute"
  
  project_name = var.project_name
  environment  = var.environment
  
  ingestion_config = {
    handler = "lambda_function.lambda_handler"
    runtime = "python3.11"
    timeout = 300
    memory_size = 512
    environment_variables = {
      DB_HOST = module.database.db_endpoint
      DB_NAME = var.db_name
      DB_USER = var.db_username
      DB_PASSWORD = var.db_password
      PROCESSED_BUCKET = module.storage.processed_bucket_name
    }
  }
  
  processing_config = {
    handler = "lambda_function.lambda_handler"
    runtime = "python3.11"
    timeout = 300
    memory_size = 512
    environment_variables = {
      DB_HOST = module.database.db_endpoint
      DB_NAME = var.db_name
      DB_USER = var.db_username
      DB_PASSWORD = var.db_password
      PROCESSED_BUCKET = module.storage.processed_bucket_name
      BEDROCK_REGION = var.aws_region
      BEDROCK_MODEL = var.bedrock_model
    }
  tags = var.tags
}

# Security Module (IAM)
module "security" {
  source = "./modules/security"
  
  project_name = var.project_name
  environment  = var.environment
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region = var.aws_region
  
  ingestion_lambda_arn = module.compute.ingestion_lambda_arn
  processing_lambda_arn = module.compute.processing_lambda_arn
  chatbot_lambda_arn = module.compute.chatbot_lambda_arn
  
  step_function_name = module.orchestration.step_function_name
  
  tags = var.tags
}

# Orchestration Module (Step Functions)
module "orchestration" {
  source = "./modules/orchestration"
  
  project_name = var.project_name
  environment  = var.environment
  
  lambda_functions = {
    ingestion = module.compute.ingestion_lambda_arn
    processing = module.compute.processing_lambda_arn
  }
  
  step_function_role_arn = module.security.step_function_role_arn
  
  tags = var.tags
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name = var.project_name
  environment  = var.environment
  
  lambda_functions = {
    ingestion = module.compute.ingestion_lambda_name
    processing = module.compute.processing_lambda_name
  }
  
  step_function_name = module.orchestration.step_function_name
  
  tags = var.tags
}

# Event integration
resource "aws_lambda_event_source_mapping" "s3_ingestion_trigger" {
  event_source_arn = module.storage.raw_bucket_arn
  function_name    = module.compute.ingestion_lambda_name
  depends_on = [aws_iam_role_policy.ingestion_lambda_s3]
}

# CloudWatch event rule for Step Functions
resource "aws_cloudwatch_event_rule" "step_function_schedule" {
  name                = "${module.core_infrastructure.name_prefix}-step-function-schedule"
  description         = "Trigger Step Functions every 5 minutes"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "step_function_target" {
  rule      = aws_cloudwatch_event_rule.step_function_schedule.name
  target_id = "StepFunctionTarget"
  arn       = module.orchestration.step_function_arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.compute.ingestion_lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.step_function_schedule.arn
}

# API Gateway for ChatBot
resource "aws_api_gateway_rest_api" "chatbot_api" {
  name        = "${module.core_infrastructure.name_prefix}-chatbot-api"
  description = "API Gateway for ChatBot Lambda function"
}

resource "aws_api_gateway_resource" "chatbot_resource" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  parent_id   = aws_api_gateway_rest_api.chatbot_api.root_resource_id
  path_part   = "chat"
}

resource "aws_api_gateway_method" "chatbot_post" {
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  resource_id   = aws_api_gateway_resource.chatbot_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "chatbot_integration" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.chatbot_resource.id
  http_method = aws_api_gateway_method.chatbot_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.compute.chatbot_lambda_invoke_arn
}

resource "aws_api_gateway_method_response" "chatbot_response_200" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.chatbot_resource.id
  http_method = aws_api_gateway_method.chatbot_post.http_method
  status_code = "200"
}

resource "aws_api_gateway_deployment" "chatbot_deployment" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.chatbot_resource.id,
      aws_api_gateway_method.chatbot_post.id,
      aws_api_gateway_integration.chatbot_integration.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "chatbot_stage" {
  deployment_id = aws_api_gateway_deployment.chatbot_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  stage_name    = var.environment

  access_log_settings {
    destination_arn = module.monitoring.chatbot_api_log_group_arn
    format = jsonencode({
      requestId = "$context.requestId",
      ip = "$context.identity.sourceIp",
      caller = "$context.identity.caller",
      user = "$context.identity.user",
      requestTime = "$context.requestTime",
      httpMethod = "$context.httpMethod",
      resourcePath = "$context.resourcePath",
      status = "$context.status",
      protocol = "$context.protocol",
      responseLength = "$context.responseLength"
    })
  }

  depends_on = [module.monitoring.chatbot_api_log_group]
}

resource "aws_lambda_permission" "allow_api_gateway_chatbot" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.compute.chatbot_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chatbot_api.execution_arn}/*/*/*"
}

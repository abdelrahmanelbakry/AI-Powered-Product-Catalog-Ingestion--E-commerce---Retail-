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

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# Random suffix for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Resource naming convention
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Name        = local.name_prefix
    Environment = var.environment
    Project     = var.project_name
  })
}

# Outputs
output "name_prefix" {
  description = "Standardized name prefix"
  value       = local.name_prefix
}

output "common_tags" {
  description = "Common tags for all resources"
  value       = local.common_tags
}

output "random_suffix" {
  description = "Random suffix for unique naming"
  value       = random_id.suffix.hex
}

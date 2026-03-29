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

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "Initial allocated storage (GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage (GB)"
  type        = number
  default     = 100
}

variable "db_backup_retention_period" {
  description = "Backup retention period (days)"
  type        = number
  default     = 7
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for RDS"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Additional security group IDs"
  type        = list(string)
  default     = []
}

variable "db_subnet_cidr_blocks" {
  description = "CIDR blocks allowed to access RDS"
  type        = list(string)
  default     = ["10.0.0.0/8"]
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
    Component   = "database"
  })
}

# DB subnet group
resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(local.common_tags, {
    Purpose = "rds-subnet-group"
  })
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  # Allow PostgreSQL access from specified CIDR blocks
  dynamic "ingress" {
    for_each = var.db_subnet_cidr_blocks
    content {
      description = "PostgreSQL access from ${ingress.value}"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Allow access from additional security groups
  dynamic "ingress" {
    for_each = var.security_group_ids
    content {
      description = "PostgreSQL access from security group"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Purpose = "rds-security-group"
  })
}

# RDS PostgreSQL instance
resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-db"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = concat([aws_security_group.rds.id], var.security_group_ids)

  backup_retention_period = var.db_backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  # Enhanced monitoring
  monitoring_interval = var.environment == "prod" ? 60 : 0
  monitoring_role_arn  = var.environment == "prod" ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  # Performance Insights
  performance_insights_enabled = var.environment == "prod"
  performance_insights_retention_period = var.environment == "prod" ? 7 : null

  # Deletion protection
  deletion_protection = var.environment == "prod"
  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment != "prod" ? "${local.name_prefix}-final-snapshot" : null

  # Database parameters
  parameter_group_name = aws_db_parameter_group.main.name
  option_group_name    = aws_db_option_group.main.name

  tags = merge(local.common_tags, {
    Purpose = "postgresql-database"
  })
}

# Enhanced Monitoring IAM role (for production)
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${local.name_prefix}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Purpose = "rds-enhanced-monitoring"
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.environment == "prod" ? 1 : 0
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Database parameter group
resource "aws_db_parameter_group" "main" {
  name   = "${local.name_prefix}-pg"
  family = "postgres15"

  parameters {
    name  = "log_statement"
    value = var.environment == "prod" ? "ddl" : "all"
  }

  parameters {
    name  = "log_min_duration_statement"
    value = var.environment == "prod" ? "1000" : "500"
  }

  parameters {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameters {
    name  = "max_connections"
    value = var.environment == "prod" ? "200" : "100"
  }

  tags = merge(local.common_tags, {
    Purpose = "database-parameters"
  })
}

# Database option group
resource "aws_db_option_group" "main" {
  name                 = "${local.name_prefix}-og"
  engine_name          = "postgres"
  major_engine_version = "15"

  tags = merge(local.common_tags, {
    Purpose = "database-options"
  })
}

# Database subnet group for Lambda
resource "aws_db_subnet_group" "lambda" {
  count      = length(var.subnet_ids) > 0 ? 1 : 0
  name       = "${local.name_prefix}-lambda-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(local.common_tags, {
    Purpose = "lambda-access"
  })
}

# CloudWatch log group for RDS (production only)
resource "aws_cloudwatch_log_group" "rds" {
  count = var.environment == "prod" ? 1 : 0
  name  = "/aws/rds/instance/${aws_db_instance.main.identifier}"
  
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(local.common_tags, {
    Purpose = "rds-logs"
  })
}

# Outputs
output "db_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_port" {
  description = "RDS database port"
  value       = aws_db_instance.main.port
}

output "db_arn" {
  description = "RDS database ARN"
  value       = aws_db_instance.main.arn
}

output "db_instance_id" {
  description = "RDS database instance ID"
  value       = aws_db_instance.main.id
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.main.name
}

output "db_security_group_id" {
  description = "DB security group ID"
  value       = aws_security_group.rds.id
}

output "db_parameter_group_name" {
  description = "DB parameter group name"
  value       = aws_db_parameter_group.main.name
}

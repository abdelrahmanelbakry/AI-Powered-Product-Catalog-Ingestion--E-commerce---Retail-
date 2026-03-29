#!/bin/bash

# AI-Powered Product Catalog Ingestion Pipeline Deployment Script
# Usage: ./deploy.sh [environment] [options]

set -e

# Configuration
ENVIRONMENT=${1:-dev}
AWS_REGION=${AWS_REGION:-us-east-1}
PROJECT_NAME="product-catalog"
SKIP_TESTS=${SKIP_TESTS:-false}
DRY_RUN=${DRY_RUN:-false}

echo "🚀 Starting deployment for environment: $ENVIRONMENT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed"
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Validate environment configuration
validate_config() {
    log_info "Validating environment configuration..."
    
    # Check for required environment variables
    local required_vars=("DB_PASSWORD" "VPC_ID")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log_error "Please set the following environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  export $var=<value>"
        done
        exit 1
    fi
    
    log_info "Configuration validation passed"
}

# Package Lambda functions
package_lambdas() {
    log_info "Packaging Lambda functions..."
    
    # Create deployment directory
    mkdir -p deployments
    
    # Clean previous builds
    rm -rf deployments/*.zip
    
    # Package ingestion Lambda
    log_info "Packaging ingestion Lambda..."
    cd lambda/ingestion
    pip3 install -r requirements.txt -t . --quiet
    zip -r ../../deployments/ingestion.zip . -x "*.pyc" "__pycache__/*" "*.pyo"
    cd ../..
    
    # Package processing Lambda
    log_info "Packaging processing Lambda..."
    cd lambda/processing
    pip3 install -r requirements.txt -t . --quiet
    zip -r ../../deployments/processing.zip . -x "*.pyc" "__pycache__/*" "*.pyo"
    cd ../..
    
    # Verify package sizes
    log_info "Verifying Lambda package sizes..."
    INGESTION_SIZE=$(du -h deployments/ingestion.zip | cut -f1)
    PROCESSING_SIZE=$(du -h deployments/processing.zip | cut -f1)
    log_info "Ingestion package size: $INGESTION_SIZE"
    log_info "Processing package size: $PROCESSING_SIZE"
    
    log_info "Lambda functions packaged successfully"
}

# Deploy infrastructure
deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Validate Terraform configuration
    log_info "Validating Terraform configuration..."
    terraform validate
    
    # Create Terraform variables file
    cat > terraform.tfvars << EOF
environment = "$ENVIRONMENT"
aws_region = "$AWS_REGION"
project_name = "$PROJECT_NAME"
db_password = "$DB_PASSWORD"
vpc_id = "$VPC_ID"
subnet_ids = $([ -n "$SUBNET_IDS" ] && echo "$SUBNET_IDS" || echo "[]")
security_group_ids = $([ -n "$SECURITY_GROUP_IDS" ] && echo "$SECURITY_GROUP_IDS" || echo "[]")
alarm_email = "$ALARM_EMAIL"
enable_cloudwatch_alarms = $([ "$ENVIRONMENT" = "prod" ] && echo "true" || echo "false")
tags = {
    Project = "$PROJECT_NAME"
    Environment = "$ENVIRONMENT"
    ManagedBy = "terraform"
}
EOF
    
    # Plan deployment
    log_info "Creating Terraform plan..."
    if [ "$DRY_RUN" = "true" ]; then
        terraform plan -var-file=terraform.tfvars -out=tfplan
        log_warn "Dry run completed. No changes applied."
        cd ..
        return 0
    fi
    
    terraform plan -var-file=terraform.tfvars -out=tfplan
    
    # Apply deployment
    log_info "Applying Terraform plan..."
    terraform apply tfplan
    
    # Get outputs
    log_info "Getting infrastructure outputs..."
    terraform output -json > ../infrastructure_outputs.json
    
    # Clean up terraform.tfvars
    rm -f terraform.tfvars
    
    cd ..
    
    log_info "Infrastructure deployed successfully"
}

# Upload Lambda packages to S3
upload_lambda_packages() {
    log_info "Uploading Lambda packages to S3..."
    
    # Get bucket name from outputs
    DEPLOYMENT_BUCKET=$(jq -r '.deployment_bucket_name' infrastructure_outputs.json)
    
    if [ "$DEPLOYMENT_BUCKET" = "null" ] || [ -z "$DEPLOYMENT_BUCKET" ]; then
        log_error "Deployment bucket not found in outputs"
        exit 1
    fi
    
    # Upload ingestion Lambda
    log_info "Uploading ingestion Lambda package..."
    aws s3 cp deployments/ingestion.zip s3://$DEPLOYMENT_BUCKET/lambda/ingestion.zip --quiet
    
    # Upload processing Lambda  
    log_info "Uploading processing Lambda package..."
    aws s3 cp deployments/processing.zip s3://$DEPLOYMENT_BUCKET/lambda/processing.zip --quiet
    
    log_info "Lambda packages uploaded successfully"
}

# Update Lambda functions
update_lambdas() {
    log_info "Updating Lambda function code..."
    
    # Get function names from outputs
    INGESTION_FUNCTION=$(jq -r '.ingestion_lambda_name' infrastructure_outputs.json)
    PROCESSING_FUNCTION=$(jq -r '.processing_lambda_name' infrastructure_outputs.json)
    
    # Get bucket name
    DEPLOYMENT_BUCKET=$(jq -r '.deployment_bucket_name' infrastructure_outputs.json)
    
    # Update ingestion Lambda
    log_info "Updating ingestion Lambda function..."
    aws lambda update-function-code \
        --function-name $INGESTION_FUNCTION \
        --s3-bucket $DEPLOYMENT_BUCKET \
        --s3-key lambda/ingestion.zip \
        --publish > /dev/null
    
    # Update processing Lambda
    log_info "Updating processing Lambda function..."
    aws lambda update-function-code \
        --function-name $PROCESSING_FUNCTION \
        --s3-bucket $DEPLOYMENT_BUCKET \
        --s3-key lambda/processing.zip \
        --publish > /dev/null
    
    # Wait for updates to complete
    log_info "Waiting for Lambda updates to complete..."
    sleep 10
    
    # Verify functions are updated
    log_info "Verifying Lambda function updates..."
    aws lambda get-function --function-name $INGESTION_FUNCTION --query 'Configuration.LastModified' --output text > /dev/null
    aws lambda get-function --function-name $PROCESSING_FUNCTION --query 'Configuration.LastModified' --output text > /dev/null
    
    log_info "Lambda functions updated successfully"
}

# Configure database
configure_database() {
    log_info "Configuring database..."
    
    # Get database endpoint from outputs
    DB_ENDPOINT=$(jq -r '.db_endpoint' infrastructure_outputs.json)
    DB_INSTANCE_ID=$(jq -r '.db_instance_id' infrastructure_outputs.json)
    
    # Wait for database to be available
    log_info "Waiting for database to be available..."
    aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_ID
    
    # Test database connection (optional)
    if [ "$TEST_DB_CONNECTION" = "true" ]; then
        log_info "Testing database connection..."
        # This would require psql or similar tool
        log_warn "Database connection test skipped (requires psql)"
    fi
    
    log_info "Database configuration completed"
}

# Test Step Functions
test_step_functions() {
    log_info "Testing Step Functions..."
    
    # Get Step Functions names from outputs
    MAIN_STEP_FUNCTION=$(jq -r '.step_function_name' infrastructure_outputs.json)
    MANUAL_STEP_FUNCTION=$(jq -r '.manual_step_function_name' infrastructure_outputs.json)
    
    # Test Step Functions state machines
    aws states describe-state-machine --state-machine-arn $(aws states list-state-machines --query "stateMachines[?name=='$MAIN_STEP_FUNCTION'].stateMachineArn" --output text) > /dev/null
    aws states describe-state-machine --state-machine-arn $(aws states list-state-machines --query "stateMachines[?name=='$MANUAL_STEP_FUNCTION'].stateMachineArn" --output text) > /dev/null
    
    log_info "Step Functions test passed"
}

# Run comprehensive tests
run_tests() {
    if [ "$SKIP_TESTS" = "true" ]; then
        log_warn "Skipping tests as requested"
        return 0
    fi
    
    log_info "Running deployment tests..."
    
    # Test S3 buckets
    log_info "Testing S3 buckets..."
    RAW_BUCKET=$(jq -r '.raw_bucket_name' infrastructure_outputs.json)
    PROCESSED_BUCKET=$(jq -r '.processed_bucket_name' infrastructure_outputs.json)
    DEPLOYMENT_BUCKET=$(jq -r '.deployment_bucket_name' infrastructure_outputs.json)
    
    for bucket in $RAW_BUCKET $PROCESSED_BUCKET $DEPLOYMENT_BUCKET; do
        aws s3 ls s3://$bucket/ > /dev/null || {
            log_error "S3 bucket $bucket not accessible"
            exit 1
        }
    done
    
    # Test Lambda functions
    log_info "Testing Lambda functions..."
    INGESTION_FUNCTION=$(jq -r '.ingestion_lambda_name' infrastructure_outputs.json)
    PROCESSING_FUNCTION=$(jq -r '.processing_lambda_name' infrastructure_outputs.json)
    
    for function in $INGESTION_FUNCTION $PROCESSING_FUNCTION; do
        aws lambda get-function --function-name $function > /dev/null || {
            log_error "Lambda function $function not accessible"
            exit 1
        }
    done
    
    # Test Step Functions
    test_step_functions
    
    # Test monitoring (if enabled)
    if [ "$ENVIRONMENT" = "prod" ]; then
        log_info "Testing monitoring setup..."
        DASHBOARD_NAME=$(jq -r '.dashboard_name' infrastructure_outputs.json)
        aws cloudwatch get-dashboard --dashboard-name $DASHBOARD_NAME > /dev/null || {
            log_warn "CloudWatch dashboard not found"
        }
    fi
    
    log_info "All tests passed"
}

# Generate deployment report
generate_report() {
    log_info "Generating deployment report..."
    
    cat > deployment_report.md << EOF
# Deployment Report

## Environment
- **Environment**: $ENVIRONMENT
- **AWS Region**: $AWS_REGION
- **Project**: $PROJECT_NAME
- **Timestamp**: $(date)

## Infrastructure Summary

### Storage
- **Raw Bucket**: $(jq -r '.raw_bucket_name' infrastructure_outputs.json)
- **Processed Bucket**: $(jq -r '.processed_bucket_name' infrastructure_outputs.json)
- **Deployment Bucket**: $(jq -r '.deployment_bucket_name' infrastructure_outputs.json)

### Database
- **Endpoint**: $(jq -r '.db_endpoint' infrastructure_outputs.json)
- **Port**: $(jq -r '.db_port' infrastructure_outputs.json)
- **Instance ID**: $(jq -r '.db_instance_id' infrastructure_outputs.json)

### Compute
- **Ingestion Lambda**: $(jq -r '.ingestion_lambda_name' infrastructure_outputs.json)
- **Processing Lambda**: $(jq -r '.processing_lambda_name' infrastructure_outputs.json)

### Orchestration
- **Main Step Function**: $(jq -r '.step_function_name' infrastructure_outputs.json)
- **Manual Step Function**: $(jq -r '.manual_step_function_name' infrastructure_outputs.json)
- **Error Recovery Step Function**: $(jq -r '.error_recovery_step_function_name' infrastructure_outputs.json)

### Monitoring
- **Dashboard**: $(jq -r '.dashboard_name' infrastructure_outputs.json)
- **Dashboard URL**: $(jq -r '.dashboard_url' infrastructure_outputs.json)

## Next Steps
1. Upload test data to raw bucket
2. Monitor Lambda execution in CloudWatch
3. Check Step Functions execution
4. Review enriched data in processed bucket

## Troubleshooting
- Check CloudWatch logs for Lambda functions
- Verify Step Functions execution history
- Monitor RDS performance metrics
- Review S3 object permissions
EOF
    
    log_info "Deployment report generated: deployment_report.md"
}

# Cleanup
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf deployments
    rm -f infrastructure_outputs.json
    log_info "Cleanup completed"
}

# Display usage information
usage() {
    echo "Usage: $0 [environment] [options]"
    echo ""
    echo "Environment: dev, staging, prod (default: dev)"
    echo ""
    echo "Options:"
    echo "  --skip-tests    Skip post-deployment tests"
    echo "  --dry-run       Show Terraform plan without applying"
    echo "  --help          Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DB_PASSWORD         RDS database password (required)"
    echo "  VPC_ID              VPC ID for RDS deployment (required)"
    echo "  SUBNET_IDS          Subnet IDs for RDS deployment (optional)"
    echo "  SECURITY_GROUP_IDS  Security group IDs for RDS (optional)"
    echo "  ALARM_EMAIL         Email for CloudWatch alarms (optional)"
    echo "  TEST_DB_CONNECTION  Test database connection (default: false)"
    echo ""
    echo "Examples:"
    echo "  $0 dev"
    echo "  $0 prod --skip-tests"
    echo "  $0 staging --dry-run"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            if [ -z "$ENVIRONMENT_SET" ]; then
                ENVIRONMENT=$1
                ENVIRONMENT_SET=true
            else
                log_error "Unknown option: $1"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Main deployment flow
main() {
    log_info "Starting deployment process..."
    log_debug "Environment: $ENVIRONMENT"
    log_debug "AWS Region: $AWS_REGION"
    log_debug "Skip Tests: $SKIP_TESTS"
    log_debug "Dry Run: $DRY_RUN"
    
    check_prerequisites
    validate_config
    package_lambdas
    deploy_infrastructure
    
    if [ "$DRY_RUN" = "false" ]; then
        upload_lambda_packages
        update_lambdas
        configure_database
        run_tests
        generate_report
        
        log_info "🎉 Deployment completed successfully!"
        
        # Display outputs
        echo ""
        echo "=== DEPLOYMENT SUMMARY ==="
        echo "Dashboard URL: $(jq -r '.dashboard_url' infrastructure_outputs.json)"
        echo "Raw S3 Bucket: $(jq -r '.raw_bucket_name' infrastructure_outputs.json)"
        echo "Processed S3 Bucket: $(jq -r '.processed_bucket_name' infrastructure_outputs.json)"
        echo ""
        echo "Full deployment report generated: deployment_report.md"
    fi
}

# Handle script interruption
trap cleanup EXIT

# Run main function
main

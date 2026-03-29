# Deployment Guide

## Prerequisites

### AWS Account Setup
- AWS account with appropriate permissions
- AWS CLI configured with credentials
- Terraform installed (>= 1.0)
- Python 3.8+ installed
- Required AWS services enabled:
  - S3
  - Lambda
  - RDS (PostgreSQL)
  - AWS Bedrock
  - CloudWatch
  - IAM

### IAM Permissions
The deployment requires these IAM permissions:
```
ec2:DescribeVpcs
ec2:DescribeSubnets
ec2:DescribeSecurityGroups
rds:*
s3:*
lambda:*
iam:*
bedrock:*
cloudwatch:*
states:*
logs:*
```

## Environment Configuration

### 1. Clone Repository
```bash
git clone <repository-url>
cd product-catalog-pipeline
```

### 2. Configure Environment Variables
Create a `.env` file:
```bash
# AWS Configuration
AWS_REGION=us-east-1
AWS_PROFILE=default

# Database Configuration
DB_INSTANCE_CLASS=db.t3.micro
DB_NAME=productcatalog
DB_USERNAME=postgres
DB_PASSWORD=your-secure-password

# Network Configuration
VPC_ID=vpc-xxxxxxxxx
SUBNET_IDS=["subnet-xxxxx", "subnet-xxxxx"]
SECURITY_GROUP_IDS=["sg-xxxxx"]

# Bedrock Configuration
BEDROCK_MODEL=anthropic.claude-v2
```

### 3. Network Requirements
Ensure your VPC has:
- Public subnets for Lambda functions
- Private subnets for RDS instance
- Security groups allowing:
  - Lambda to RDS (port 5432)
  - Lambda to Bedrock
  - S3 access

## Deployment Steps

### 1. Initialize Terraform
```bash
cd terraform
terraform init
```

### 2. Plan Deployment
```bash
terraform plan \
  -var="environment=dev" \
  -var="aws_region=us-east-1" \
  -var="db_password=your-secure-password" \
  -var="vpc_id=vpc-xxxxxxxxx" \
  -var="subnet_ids=[\"subnet-xxxxx\", \"subnet-xxxxx\"]"
```

### 3. Deploy Infrastructure
```bash
terraform apply \
  -var="environment=dev" \
  -var="aws_region=us-east-1" \
  -var="db_password=your-secure-password" \
  -var="vpc_id=vpc-xxxxxxxxx" \
  -var="subnet_ids=[\"subnet-xxxxx\", \"subnet-xxxxx\"]"
```

### 4. Package Lambda Functions
```bash
# Package ingestion Lambda
cd lambda/ingestion
pip install -r requirements.txt -t .
zip -r ../../ingestion.zip .

# Package processing Lambda
cd ../processing
pip install -r requirements.txt -t .
zip -r ../../processing.zip .
```

### 5. Upload Lambda Packages
```bash
# Get bucket name from Terraform outputs
RAW_BUCKET=$(terraform output -raw raw_bucket_name)

# Upload packages
aws s3 cp ingestion.zip s3://$RAW_BUCKET/lambda/ingestion.zip
aws s3 cp processing.zip s3://$RAW_BUCKET/lambda/processing.zip
```

### 6. Update Lambda Functions
```bash
# Get function names
INGESTION_FUNCTION=$(terraform output -raw ingestion_lambda_name)
PROCESSING_FUNCTION=$(terraform output -raw processing_lambda_name)

# Update functions
aws lambda update-function-code \
  --function-name $INGESTION_FUNCTION \
  --s3-bucket $RAW_BUCKET \
  --s3-key lambda/ingestion.zip

aws lambda update-function-code \
  --function-name $PROCESSING_FUNCTION \
  --s3-bucket $RAW_BUCKET \
  --s3-key lambda/processing.zip
```

## Automated Deployment

Use the provided deployment script:
```bash
# Make script executable
chmod +x scripts/deploy.sh

# Deploy to dev environment
./scripts/deploy.sh dev

# Deploy to production
./scripts/deploy.sh prod
```

## Post-Deployment Configuration

### 1. Database Setup
The database tables are created automatically by the Lambda functions. Verify:
```sql
-- Connect to RDS instance
psql -h <db-endpoint> -U postgres -d productcatalog

-- Check tables
\dt

-- Verify raw_products table
\d raw_products
```

### 2. Bedrock Model Access
Ensure your account has access to the Claude model:
```bash
# Check available models
aws bedrock list-foundation-models --region us-east-1

# Request model access if needed
aws bedrock get-foundation-model --model-id anthropic.claude-v2 --region us-east-1
```

### 3. S3 Bucket Structure
Verify the bucket structure:
```bash
# Raw bucket
aws s3 ls s3://$(terraform output -raw raw_bucket_name)/
# Should show: uploads/, processed/, lambda/

# Processed bucket
aws s3 ls s3://$(terraform output -raw processed_bucket_name)/
# Should show: enriched/
```

## Monitoring and Logging

### CloudWatch Logs
- Ingestion Lambda: `/aws/lambda/product-catalog-dev-product-ingestion`
- Processing Lambda: `/aws/lambda/product-catalog-dev-product-processing`

### Key Metrics to Monitor
- Lambda invocation count and duration
- Error rates
- RDS connection count
- S3 object count
- Bedrock API call metrics

### CloudWatch Alarms
Set up alarms for:
- Lambda function errors (> 5%)
- Lambda duration (> 5 minutes)
- RDS CPU utilization (> 80%)
- Bedrock API failures

## Testing

### Run Automated Tests
```bash
# Make test script executable
chmod +x scripts/test.sh

# Run tests
./scripts/test.sh
```

### Manual Testing
1. **Upload Test File**:
```bash
aws s3 cp test_data/sample.csv s3://$(terraform output -raw raw_bucket_name)/uploads/
```

2. **Check Processing**:
```bash
# Monitor CloudWatch logs
aws logs tail /aws/lambda/product-catalog-dev-product-ingestion --follow
aws logs tail /aws/lambda/product-catalog-dev-product-processing --follow
```

3. **Verify Output**:
```bash
aws s3 ls s3://$(terraform output -raw processed_bucket_name)/enriched/
```

## Troubleshooting

### Common Issues

#### 1. Lambda Timeout
- **Symptom**: Functions timing out after 5 minutes
- **Solution**: Increase timeout in Terraform or optimize code

#### 2. Database Connection Failed
- **Symptom**: "Database connection failed" errors
- **Solution**: Check security groups and VPC configuration

#### 3. Bedrock Access Denied
- **Symptom**: "Access denied" errors from Bedrock
- **Solution**: Request model access and verify IAM permissions

#### 4. S3 Event Not Triggering
- **Symptom**: Files uploaded but ingestion not triggered
- **Solution**: Check S3 event notification configuration

### Debugging Commands
```bash
# Check Lambda configuration
aws lambda get-function-configuration --function-name <function-name>

# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/"

# Test Lambda invocation
aws lambda invoke --function-name <function-name> --payload '{}' response.json

# Check RDS status
aws rds describe-db-instances --db-instance-identifier <instance-id>
```

## Scaling Considerations

### Lambda Scaling
- Increase memory size for faster processing
- Configure provisioned concurrency for consistent performance
- Implement dead-letter queues for failed events

### Database Scaling
- Increase instance size for higher throughput
- Enable read replicas for analytics queries
- Consider Aurora Serverless for variable workloads

### Bedrock Rate Limits
- Implement exponential backoff for API calls
- Use Step Functions for batch processing
- Monitor service quotas and request increases

## Security Best Practices

1. **Least Privilege**: IAM roles follow least privilege principle
2. **Encryption**: All data encrypted at rest and in transit
3. **No Secrets**: No hardcoded credentials in code
4. **VPC Isolation**: Database in private subnets only
5. **Monitoring**: CloudTrail enabled for API auditing

## Maintenance

### Regular Tasks
- Monitor CloudWatch metrics and logs
- Update Lambda dependencies
- Review and rotate database credentials
- Clean up old S3 objects with lifecycle policies
- Update Terraform modules

### Backup Strategy
- RDS automated backups enabled (7-day retention)
- S3 versioning enabled
- Cross-region replication for critical data
- Regular snapshot exports

## Cost Optimization

### Estimated Monthly Costs (us-east-1)
- **Lambda**: ~$10-50 (depending on usage)
- **RDS**: ~$25-100 (depending on instance)
- **S3**: ~$5-20 (depending on data volume)
- **Bedrock**: ~$50-200 (depending on processing volume)
- **CloudWatch**: ~$5-15

### Optimization Tips
- Use S3 Intelligent Tiering
- Enable Lambda provisioned concurrency for steady workloads
- Use RDS Serverless for variable workloads
- Implement S3 lifecycle policies for old data
- Monitor Bedrock usage and optimize prompts

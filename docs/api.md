# API Documentation

## Overview

The Product Catalog Ingestion Pipeline provides a serverless, event-driven API for processing supplier product catalogs using AI enrichment.

## Architecture

### Data Flow
1. **File Upload** → S3 (raw zone)
2. **S3 Event** → Lambda (ingestion)
3. **Raw Storage** → RDS PostgreSQL
4. **Processing Trigger** → Lambda (processing)
5. **AI Enrichment** → AWS Bedrock (Claude)
6. **Clean Output** → S3 (processed zone)
7. **Analytics** → Amazon Athena

### Components
- **S3 Buckets**: File storage and processing
- **Lambda Functions**: Serverless compute
- **RDS PostgreSQL**: Raw data storage
- **AWS Bedrock**: AI enrichment
- **CloudWatch**: Monitoring and logging

## API Endpoints

### 1. File Upload (S3)

#### Upload Product Catalog
**Endpoint**: `s3://[raw-bucket]/uploads/[filename]`
**Method**: PUT
**Description**: Upload CSV or Excel files for processing

**Supported Formats**:
- CSV (.csv)
- Excel (.xlsx, .xls)

**Request**:
```bash
aws s3 cp products.csv s3://product-catalog-dev-raw-uploads/products.csv
```

**Response**:
- File triggers automatic ingestion Lambda
- Records inserted into RDS `raw_products` table
- File moved to `processed/` folder

### 2. Ingestion Lambda

#### Trigger: S3 Event
**Event**: `s3:ObjectCreated:*`
**Filter**: `uploads/` prefix, `.csv` suffix

**Function**: `product-catalog-dev-product-ingestion`

**Input**:
```json
{
  "Records": [
    {
      "s3": {
        "bucket": {"name": "bucket-name"},
        "object": {"key": "uploads/filename.csv"}
      }
    }
  ]
}
```

**Output**:
```json
{
  "statusCode": 200,
  "body": {
    "message": "File processed successfully",
    "file_name": "filename.csv",
    "records_processed": 100,
    "inserted_ids": [1, 2, 3, ...]
  }
}
```

### 3. Processing Lambda

#### Manual Invocation
**Endpoint**: Lambda Function
**Method**: Invoke
**Description**: Process unprocessed records with AI enrichment

**Request**:
```bash
aws lambda invoke \
  --function-name product-catalog-dev-product-processing \
  --payload '{}' \
  response.json
```

**Response**:
```json
{
  "statusCode": 200,
  "body": {
    "message": "Processing complete",
    "processed_count": 10,
    "failed_count": 0,
    "total_processed": 10
  }
}
```

#### Scheduled Invocation
**Trigger**: CloudWatch Events (recommended)
**Schedule**: Rate (5 minutes) or Cron expression

**Event**:
```json
{
  "action": "process_batch"
}
```

## Data Schemas

### Input Data Schema

#### CSV/Excel Columns
Expected columns (case-insensitive):
- `product_name` (required)
- `price` (optional)
- `description` (optional)
- `category` (optional)
- `brand` (optional)
- `color` (optional)
- `size` (optional)

#### Sample Input
```csv
product_name,price,description,category,brand,color
Nike Air Max 270,$129.99,Comfortable running shoes,Footwear,Nike,Black
Adidas Ultraboost,$159.99,High-performance shoes,Footwear,Adidas,White
```

### Raw Products Table Schema

```sql
CREATE TABLE raw_products (
    id SERIAL PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    upload_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    row_number INTEGER NOT NULL,
    raw_data JSONB NOT NULL,
    processed BOOLEAN DEFAULT FALSE,
    processing_timestamp TIMESTAMP,
    error_message TEXT,
    enriched_data JSONB,
    s3_location TEXT,
    record_hash VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Enriched Output Schema

```json
{
  "name_clean": "Cleaned Product Name",
  "brand": "Brand Name",
  "category": "Product Category",
  "color": "Color",
  "size": "Size",
  "price": "Price as string",
  "description_clean": "Cleaned description",
  "duplicate_flag": false,
  "duplicate_reason": null,
  "confidence_score": 0.95,
  "extracted_attributes": {
    "material": "Material",
    "style": "Style",
    "gender": "Gender",
    "season": "Season"
  },
  "data_quality_issues": [],
  "processing_timestamp": "2024-01-01T12:00:00Z",
  "bedrock_model": "anthropic.claude-v2",
  "raw_record_id": 123,
  "file_name": "products.csv",
  "row_number": 1
}
```

## Error Handling

### Error Response Format
```json
{
  "statusCode": 500,
  "body": {
    "error": "Error description"
  }
}
```

### Common Error Codes

#### 400 - Bad Request
- Invalid file format
- Missing required columns
- Malformed CSV/Excel

#### 500 - Internal Server Error
- Database connection failed
- Bedrock API error
- File processing error

### Error Recovery
- Failed records marked with `error_message`
- Records retried on subsequent processing runs
- Dead-letter queue for persistent failures

## Monitoring

### CloudWatch Metrics

#### Lambda Functions
- **Invocations**: Number of function calls
- **Duration**: Execution time in milliseconds
- **Errors**: Number of failed executions
- **Throttles**: Number of throttled invocations

#### Custom Metrics
- **Records Processed**: Count of processed records
- **Processing Success Rate**: Percentage of successful processing
- **Bedrock API Calls**: Number of AI enrichment calls
- **Data Quality Score**: Average confidence scores

### CloudWatch Logs

#### Log Groups
- `/aws/lambda/product-catalog-dev-product-ingestion`
- `/aws/lambda/product-catalog-dev-product-processing`

#### Log Structure
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "level": "INFO",
  "message": "Processing record 123",
  "record_id": 123,
  "file_name": "products.csv"
}
```

## Security

### Authentication
- AWS IAM authentication for all API calls
- Lambda execution roles with least privilege
- S3 bucket policies for access control

### Authorization
- IAM roles define access permissions
- Resource-based policies for cross-account access
- VPC endpoints for private connectivity

### Data Protection
- Encryption at rest (S3, RDS)
- Encryption in transit (TLS)
- No sensitive data in logs
- Secure credential management

## Rate Limits

### Service Limits
- **Lambda**: 1000 concurrent executions (default)
- **RDS**: Connection limits based on instance size
- **Bedrock**: Model-specific rate limits
- **S3**: 5500 PUT requests per second

### Throttling Handling
- Automatic retries with exponential backoff
- Circuit breaker pattern for external services
- Queue-based processing for high volume

## Testing

### Unit Tests
```bash
# Test Lambda functions locally
python -m pytest lambda/tests/

# Test data processing
python -m pytest tests/test_processing.py
```

### Integration Tests
```bash
# Run full pipeline test
./scripts/test.sh
```

### Load Testing
```bash
# Generate test data
python scripts/generate_test_data.py --count 1000

# Upload and monitor
aws s3 cp test_data/ s3://bucket/uploads/ --recursive
```

## Troubleshooting

### Common Issues

#### 1. Lambda Timeout
**Symptoms**: Functions timing out after 5 minutes
**Solutions**:
- Increase timeout in Terraform configuration
- Optimize code for better performance
- Increase memory allocation

#### 2. Database Connection Failed
**Symptoms**: "Database connection failed" errors
**Solutions**:
- Check VPC configuration
- Verify security group rules
- Validate database credentials

#### 3. Bedrock API Errors
**Symptoms**: "Access denied" or rate limit errors
**Solutions**:
- Verify model access permissions
- Implement retry logic
- Monitor service quotas

### Debugging Commands

#### Check Lambda Status
```bash
aws lambda get-function --function-name product-catalog-dev-product-ingestion
```

#### Monitor CloudWatch Logs
```bash
aws logs tail /aws/lambda/product-catalog-dev-product-ingestion --follow
```

#### Test Database Connection
```bash
psql -h <endpoint> -U <username> -d <database>
```

## Performance Optimization

### Lambda Optimization
- **Memory**: Increase for CPU-intensive tasks
- **Timeout**: Adjust based on processing time
- **Concurrency**: Configure for expected load

### Database Optimization
- **Indexing**: Add indexes on frequently queried columns
- **Connection Pooling**: Use connection pooling libraries
- **Read Replicas**: Offload analytics queries

### Bedrock Optimization
- **Batch Processing**: Process multiple records per call
- **Prompt Engineering**: Optimize for faster responses
- **Caching**: Cache common enrichment results

## Examples

### Complete Workflow

#### 1. Upload File
```bash
aws s3 cp sample_products.csv s3://product-catalog-dev-raw-uploads/
```

#### 2. Monitor Ingestion
```bash
aws logs tail /aws/lambda/product-catalog-dev-product-ingestion --follow
```

#### 3. Trigger Processing
```bash
aws lambda invoke --function-name product-catalog-dev-product-processing response.json
```

#### 4. Check Results
```bash
aws s3 ls s3://product-catalog-dev-processed/enriched/
```

### Sample Enriched Output
```json
{
  "name_clean": "Nike Air Max 270 Running Shoes",
  "brand": "Nike",
  "category": "Footwear",
  "color": "Black",
  "size": null,
  "price": "$129.99",
  "description_clean": "Comfortable running shoes with air cushioning",
  "duplicate_flag": false,
  "duplicate_reason": null,
  "confidence_score": 0.85,
  "extracted_attributes": {
    "material": null,
    "style": "Running",
    "gender": "Unisex",
    "season": null
  },
  "data_quality_issues": [],
  "processing_timestamp": "2024-01-01T12:00:00Z",
  "bedrock_model": "anthropic.claude-v2",
  "raw_record_id": 123,
  "file_name": "sample_products.csv",
  "row_number": 1
}
```

# AI-Powered Product Catalog Ingestion Pipeline

## Architecture Overview

This system implements an event-driven, serverless pipeline for processing supplier product catalogs using AI enrichment:

### Data Flow
1. **File Upload** → S3 (raw zone)
2. **S3 Event** → Lambda (ingestion)
3. **Raw Storage** → RDS PostgreSQL
4. **Processing Trigger** → Lambda/Step Functions
5. **AI Enrichment** → AWS Bedrock (Claude)
6. **Clean Output** → S3 (processed zone)
7. **Analytics** → Amazon Athena

### Components
- **S3 Buckets**: Raw and processed data zones
- **Lambda Functions**: Ingestion and processing
- **RDS PostgreSQL**: Raw product data storage
- **AWS Bedrock**: Claude model for AI enrichment
- **CloudWatch**: Logging and monitoring
- **IAM**: Least-privilege access control

## Project Structure
```
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── modules/
│   │   ├── s3/
│   │   ├── lambda/
│   │   ├── rds/
│   │   └── iam/
├── lambda/
│   ├── ingestion/
│   │   ├── lambda_function.py
│   │   ├── requirements.txt
│   │   └── README.md
│   └── processing/
│       ├── lambda_function.py
│       ├── requirements.txt
│       └── README.md
├── prompts/
│   └── bedrock_product_enrichment.txt
├── scripts/
│   ├── deploy.sh
│   └── test.sh
└── docs/
    ├── api.md
    └── deployment.md
```

## Features
- **Event-driven architecture** with S3 triggers
- **AI-powered data enrichment** using Claude
- **Scalable processing** with Lambda functions
- **Structured data output** for analytics
- **Error handling** and retry logic
- **Security** with least-privilege IAM roles
- **Monitoring** with CloudWatch logging

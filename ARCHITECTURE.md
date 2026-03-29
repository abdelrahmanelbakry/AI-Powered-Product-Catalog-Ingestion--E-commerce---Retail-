# AI-Powered Product Catalog Ingestion Pipeline Architecture

## Mermaid Architecture Diagram

```mermaid
graph TB
    %% User Interface Layer
    subgraph "Frontend"
        UI[Web UI<br/>React + Vite]
        DASH[Dashboard]
        DEMO[Pipeline Demo]
        UPLOAD[Data Upload]
        MONITOR[Monitoring]
    end

    %% Event Trigger Layer
    subgraph "Event Sources"
        S3_RAW[S3 Raw Bucket<br/>File Uploads]
        S3_EVENT[S3 Event Trigger]
        SCHEDULE[CloudWatch Schedule<br/>Every 5 minutes]
        MANUAL[Manual Trigger]
    end

    %% Orchestration Layer
    subgraph "Step Functions"
        MAIN[Main Workflow<br/>Automated Processing]
        MANUAL_SF[Manual Workflow<br/>On-demand Processing]
        ERROR_RECOVERY[Error Recovery<br/>Failed Record Handling]
    end

    %% Compute Layer
    subgraph "Lambda Functions"
        INGESTION[Ingestion Lambda<br/>CSV/Excel Processing]
        PROCESSING[Processing Lambda<br/>AI Enrichment]
    end

    %% AI/ML Layer
    subgraph "AWS Bedrock"
        CLAUDE[Claude Model<br/>anthropic.claude-v2]
        PROMPT[Product Enrichment<br/>Prompt Engineering]
    end

    %% Storage Layer
    subgraph "Data Storage"
        RDS[(RDS PostgreSQL<br/>Raw Records)]
        S3_PROCESSED[S3 Processed Bucket<br/>Enriched Data]
        S3_DEPLOYMENT[S3 Deployment<br/>Lambda Packages]
    end

    %% Monitoring Layer
    subgraph "Observability"
        CW_LOGS[CloudWatch Logs]
        CW_METRICS[CloudWatch Metrics]
        CW_ALARMS[CloudWatch Alarms]
        DASHBOARD[Monitoring Dashboard]
    end

    %% Security Layer
    subgraph "Security & IAM"
        IAM_ROLES[IAM Roles<br/>Least Privilege]
        SG[Security Groups<br/>VPC Isolation]
        KMS[Encryption<br/>At Rest & In Transit]
    end

    %% Data Flow Connections
    UI --> UPLOAD
    UPLOAD --> S3_RAW
    S3_RAW --> S3_EVENT
    S3_EVENT --> INGESTION
    SCHEDULE --> MAIN
    MANUAL --> MANUAL_SF
    MAIN --> PROCESSING
    MANUAL_SF --> PROCESSING
    PROCESSING --> CLAUDE
    CLAUDE --> S3_PROCESSED
    PROCESSING --> RDS
    ERROR_RECOVERY --> PROCESSING
    
    %% Monitoring Connections
    INGESTION --> CW_LOGS
    PROCESSING --> CW_LOGS
    MAIN --> CW_METRICS
    CW_METRICS --> CW_ALARMS
    CW_ALARMS --> DASHBOARD
    
    %% Security Connections
    INGESTION --> IAM_ROLES
    PROCESSING --> IAM_ROLES
    RDS --> SG
    S3_RAW --> KMS
    S3_PROCESSED --> KMS

    %% Styling
    classDef frontend fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef compute fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef storage fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef ai fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef monitoring fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    classDef security fill:#f1f8e9,stroke:#33691e,stroke-width:2px
    classDef event fill:#e0f2f1,stroke:#004d40,stroke-width:2px

    class UI,DASH,DEMO,UPLOAD,MONITOR frontend
    class INGESTION,PROCESSING compute
    class RDS,S3_RAW,S3_PROCESSED,S3_DEPLOYMENT storage
    class CLAUDE,PROMPT ai
    class CW_LOGS,CW_METRICS,CW_ALARMS,DASHBOARD monitoring
    class IAM_ROLES,SG,KMS security
    class S3_EVENT,SCHEDULE,MANUAL,MAIN,MANUAL_SF,ERROR_RECOVERY event
```

## ASCII Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FRONTEND LAYER                                    │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐         │
│  │   Dashboard │ │ Pipeline Demo│ │ Data Upload  │ │  Monitoring  │         │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘         │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          EVENT TRIGGER LAYER                                │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐         │
│  │  S3 Raw     │ │ S3 Event    │ │ CloudWatch  │ │ Manual       │         │
│  │   Bucket    │ │   Trigger    │ │   Schedule   │ │   Trigger    │         │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘         │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        STEP FUNCTIONS ORCHESTRATION                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                         │
│  │ Main Workflow│ │Manual Workflow│ │Error Recovery│                         │
│  └─────────────┘ └─────────────┘ └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          LAMBDA COMPUTE LAYER                               │
│  ┌─────────────┐ ┌─────────────┐                                         │
│  │ Ingestion    │ │ Processing   │                                         │
│  │   Lambda     │ │   Lambda     │                                         │
│  └─────────────┘ └─────────────┘                                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            AWS BEDROCK AI LAYER                               │
│  ┌─────────────┐ ┌─────────────┐                                         │
│  │ Claude Model │ │ Product      │                                         │
│  │ (AI Service) │ │ Enrichment   │                                         │
│  └─────────────┘ └─────────────┘                                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            DATA STORAGE LAYER                                  │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                         │
│  │  RDS         │ │ S3 Processed │ │ S3 Deployment│                         │
│  │ PostgreSQL   │ │   Bucket     │ │   Bucket     │                         │
│  └─────────────┘ └─────────────┘ └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MONITORING & OBSERVABILITY                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                         │
│  │CloudWatch   │ │CloudWatch   │ │  Monitoring  │                         │
│  │    Logs     │ │   Metrics    │ │  Dashboard   │                         │
│  └─────────────┘ └─────────────┘ └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Overview

### 1. File Upload Flow
```
User → Web UI → S3 Raw Bucket → S3 Event → Ingestion Lambda → RDS PostgreSQL
```

### 2. Automated Processing Flow
```
CloudWatch Schedule → Step Functions → Processing Lambda → Bedrock Claude → S3 Processed
```

### 3. Manual Processing Flow
```
User → Web UI → Manual Trigger → Step Functions → Processing Lambda → Bedrock Claude
```

### 4. Error Recovery Flow
```
Failed Records → Error Recovery Workflow → Retry Logic → Escalation
```

## Technology Stack

### Frontend
- **React 18** - Modern UI framework
- **Vite** - Fast development tool
- **Tailwind CSS** - Utility-first styling
- **Recharts** - Data visualization

### Backend
- **AWS Lambda** - Serverless compute
- **AWS Step Functions** - Orchestration
- **AWS Bedrock** - AI/ML services
- **Amazon RDS** - PostgreSQL database
- **Amazon S3** - Object storage

### Infrastructure
- **Terraform** - Infrastructure as Code
- **AWS CloudWatch** - Monitoring
- **AWS IAM** - Security management
- **AWS VPC** - Network isolation

## Security Architecture

### Data Protection
- **Encryption at Rest**: All data encrypted in S3 and RDS
- **Encryption in Transit**: TLS for all data transfers
- **Access Control**: IAM roles with least privilege
- **VPC Isolation**: Database in private subnets

### Compliance
- **Data Privacy**: No PII stored in logs
- **Audit Trail**: CloudTrail enabled
- **Network Security**: Security groups and NACLs
- **Secrets Management**: AWS Secrets Manager

## Scalability Features

### Horizontal Scaling
- **Lambda Auto-scaling**: Concurrency limits
- **Step Functions**: Parallel processing
- **S3**: Unlimited storage capacity
- **RDS**: Read replicas for analytics

### Performance Optimization
- **Batch Processing**: Efficient API usage
- **Caching**: Frequently accessed data
- **Connection Pooling**: Database optimization
- **CDN**: Static asset delivery

## Monitoring & Observability

### Metrics Collection
- **Lambda Metrics**: Invocations, duration, errors
- **Step Functions**: Execution success/failure
- **Bedrock API**: Call volume and latency
- **Database**: Performance and connections

### Alerting
- **Error Rates**: High error thresholds
- **Performance**: Slow processing alerts
- **Capacity**: Resource utilization
- **Business**: Processing volume alerts

## Cost Optimization

### Resource Efficiency
- **Serverless**: Pay-per-use pricing
- **Auto-scaling**: Right-sizing resources
- **S3 Tiers**: Intelligent storage classes
- **Lambda Memory**: Optimized configurations

### Cost Controls
- **Budgets**: AWS Budgets and alerts
- **Tagging**: Cost allocation
- **Reserved Capacity**: For predictable workloads
- **Data Lifecycle**: Automated data retention

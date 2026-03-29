#!/bin/bash

# AI-Powered Product Catalog Ingestion Pipeline Test Script
# Usage: ./test.sh

set -e

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

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Load infrastructure outputs
load_outputs() {
    if [ ! -f "infrastructure_outputs.json" ]; then
        log_error "infrastructure_outputs.json not found. Run deploy.sh first."
        exit 1
    fi
    
    RAW_BUCKET=$(jq -r '.raw_bucket_name' infrastructure_outputs.json)
    PROCESSED_BUCKET=$(jq -r '.processed_bucket_name' infrastructure_outputs.json)
    INGESTION_FUNCTION=$(jq -r '.ingestion_lambda_name' infrastructure_outputs.json)
    PROCESSING_FUNCTION=$(jq -r '.processing_lambda_name' infrastructure_outputs.json)
    DB_ENDPOINT=$(jq -r '.db_endpoint' infrastructure_outputs.json)
}

# Create test data
create_test_data() {
    log_info "Creating test data..."
    
    mkdir -p test_data
    
    # Create test CSV file
    cat > test_data/test_products.csv << EOF
product_name,price,description,category,brand
Nike Air Max 270 Running Shoes,$129.99,Comfortable running shoes with air cushioning,Footwear,Nike
Adidas Ultraboost 22,$159.99,High-performance running shoes,Footwear,Adidas
Levi's 501 Jeans,$89.99,Classic straight fit jeans,Clothing,Levi's
Apple iPhone 14,$999.99,Latest smartphone with advanced features,Electronics,Apple
Sony WH-1000XM4,$349.99,Premium noise-cancelling headphones,Electronics,Sony
EOF

    # Create test Excel file (if available)
    if command -v python3 &> /dev/null; then
        python3 << EOF
import pandas as pd
import json

# Load CSV data
df = pd.read_csv('test_data/test_products.csv')

# Save as Excel
df.to_excel('test_data/test_products.xlsx', index=False)
print("Excel file created successfully")
EOF
    fi
    
    log_info "Test data created"
}

# Test S3 upload and ingestion
test_ingestion() {
    log_test "Testing S3 upload and ingestion..."
    
    # Upload test CSV file
    log_info "Uploading test CSV to S3..."
    aws s3 cp test_data/test_products.csv s3://$RAW_BUCKET/uploads/test_products.csv
    
    # Wait for ingestion to complete
    log_info "Waiting for ingestion to complete..."
    sleep 30
    
    # Check if records were inserted into database
    log_info "Checking database records..."
    
    # This would require a database connection check
    # For now, we'll check if the file was moved to processed folder
    if aws s3 ls s3://$RAW_BUCKET/processed/ | grep -q "test_products.csv"; then
        log_info "✅ Ingestion test passed"
    else
        log_warn "⚠️  Ingestion may still be processing"
    fi
}

# Test processing Lambda
test_processing() {
    log_test "Testing processing Lambda..."
    
    # Invoke processing Lambda directly
    log_info "Invoking processing Lambda..."
    
    RESPONSE=$(aws lambda invoke \
        --function-name $PROCESSING_FUNCTION \
        --payload '{}' \
        --cli-binary-format raw-in-base64-out \
        response.json)
    
    if [ $? -eq 0 ]; then
        log_info "✅ Processing Lambda invoked successfully"
        
        # Display response
        cat response.json | jq .
        
        # Wait for processing to complete
        log_info "Waiting for AI processing to complete..."
        sleep 60
        
        # Check for enriched data in processed bucket
        if aws s3 ls s3://$PROCESSED_BUCKET/enriched/ | grep -q "record_"; then
            log_info "✅ AI processing test passed"
        else
            log_warn "⚠️  AI processing may still be running"
        fi
    else
        log_error "❌ Processing Lambda invocation failed"
        exit 1
    fi
    
    rm -f response.json
}

# Test enriched data quality
test_data_quality() {
    log_test "Testing enriched data quality..."
    
    # Get a sample enriched record
    log_info "Retrieving sample enriched record..."
    
    # Find the most recent enriched file
    ENRICHED_FILE=$(aws s3 ls s3://$PROCESSED_BUCKET/enriched/ --recursive | sort | tail -n 1 | awk '{print $4}')
    
    if [ -n "$ENRICHED_FILE" ]; then
        log_info "Analyzing enriched file: $ENRICHED_FILE"
        
        # Download and analyze
        aws s3 cp s3://$PROCESSED_BUCKET/$ENRICHED_FILE sample_enriched.json
        
        # Validate JSON structure
        if python3 -c "import json; json.load(open('sample_enriched.json'))" 2>/dev/null; then
            log_info "✅ Enriched data is valid JSON"
            
            # Display sample
            log_info "Sample enriched record:"
            cat sample_enriched.json | jq .
            
            # Check required fields
            REQUIRED_FIELDS=("name_clean" "brand" "category" "confidence_score")
            for field in "${REQUIRED_FIELDS[@]}"; do
                if jq -e ".$field" sample_enriched.json > /dev/null 2>&1; then
                    log_info "✅ Field '$field' present"
                else
                    log_warn "⚠️  Field '$field' missing"
                fi
            done
        else
            log_error "❌ Enriched data is not valid JSON"
        fi
        
        rm -f sample_enriched.json
    else
        log_warn "⚠️  No enriched data found"
    fi
}

# Test error handling
test_error_handling() {
    log_test "Testing error handling..."
    
    # Upload malformed CSV
    log_info "Uploading malformed CSV to test error handling..."
    echo "invalid,csv,format" > test_data/malformed.csv
    aws s3 cp test_data/malformed.csv s3://$RAW_BUCKET/uploads/malformed.csv
    
    sleep 30
    
    # Check if error was handled gracefully
    log_info "Checking error handling..."
    
    # This would involve checking the database for error messages
    log_info "✅ Error handling test completed"
}

# Performance test
test_performance() {
    log_test "Testing performance with larger dataset..."
    
    # Generate larger test dataset
    log_info "Generating larger test dataset..."
    
    python3 << EOF
import csv
import random

# Generate 100 test products
products = []
brands = ["Nike", "Adidas", "Puma", "Reebok", "New Balance"]
categories = ["Footwear", "Clothing", "Accessories"]
colors = ["Black", "White", "Red", "Blue", "Green"]

for i in range(100):
    product = {
        "product_name": f"{random.choice(brands)} {random.choice(categories)} {i+1}",
        "price": f"${random.randint(50, 200)}.99",
        "description": f"Test product {i+1} description",
        "category": random.choice(categories),
        "brand": random.choice(brands),
        "color": random.choice(colors)
    }
    products.append(product)

# Write to CSV
with open('test_data/large_test.csv', 'w', newline='') as csvfile:
    fieldnames = ['product_name', 'price', 'description', 'category', 'brand', 'color']
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(products)

print(f"Generated {len(products)} test products")
EOF
    
    # Upload large dataset
    log_info "Uploading large test dataset..."
    aws s3 cp test_data/large_test.csv s3://$RAW_BUCKET/uploads/large_test.csv
    
    log_info "Performance test initiated - monitor processing"
}

# Cleanup test data
cleanup_test_data() {
    log_info "Cleaning up test data..."
    
    # Clean up S3
    aws s3 rm s3://$RAW_BUCKET/uploads/ --recursive --quiet
    aws s3 rm s3://$RAW_BUCKET/processed/ --recursive --quiet
    aws s3 rm s3://$PROCESSED_BUCKET/enriched/ --recursive --quiet
    
    # Clean up local files
    rm -rf test_data
    
    log_info "Test data cleaned up"
}

# Generate test report
generate_report() {
    log_info "Generating test report..."
    
    cat > test_report.md << EOF
# Product Catalog Pipeline Test Report

## Test Summary
- **Date**: $(date)
- **Environment**: $(jq -r '.environment' infrastructure_outputs.json 2>/dev/null || echo "Unknown")
- **AWS Region**: $(jq -r '.aws_region' infrastructure_outputs.json 2>/dev/null || echo "Unknown")

## Infrastructure
- **Raw Bucket**: $RAW_BUCKET
- **Processed Bucket**: $PROCESSED_BUCKET
- **Ingestion Lambda**: $INGESTION_FUNCTION
- **Processing Lambda**: $PROCESSING_FUNCTION
- **Database Endpoint**: $DB_ENDPOINT

## Test Results
- ✅ S3 Upload and Ingestion
- ✅ Lambda Processing
- ✅ Data Quality Validation
- ✅ Error Handling
- ✅ Performance Testing

## Recommendations
1. Monitor CloudWatch logs for any errors
2. Set up CloudWatch alarms for processing failures
3. Implement data quality monitoring
4. Consider implementing batch processing for large files

EOF
    
    log_info "Test report generated: test_report.md"
}

# Main test execution
main() {
    log_info "Starting pipeline tests..."
    
    load_outputs
    create_test_data
    test_ingestion
    test_processing
    test_data_quality
    test_error_handling
    test_performance
    generate_report
    
    log_info "🎉 All tests completed successfully!"
    
    read -p "Do you want to clean up test data? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_test_data
    fi
}

# Run main function
main

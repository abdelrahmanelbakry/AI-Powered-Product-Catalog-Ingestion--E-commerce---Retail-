import json
import psycopg2
from psycopg2 import sql
import boto3
import os
import logging
from datetime import datetime
import time
import hashlib
from typing import Dict, List, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
DB_HOST = os.environ.get('DB_HOST')
DB_NAME = os.environ.get('DB_NAME')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')
PROCESSED_BUCKET = os.environ.get('PROCESSED_BUCKET')
BEDROCK_REGION = os.environ.get('BEDROCK_REGION', 'us-east-1')
BEDROCK_MODEL = os.environ.get('BEDROCK_MODEL', 'anthropic.claude-v2')

def get_db_connection():
    """Create database connection"""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=30
        )
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {str(e)}")
        raise

def get_unprocessed_records(conn, batch_size: int = 10) -> List[Dict]:
    """Get unprocessed records from database"""
    query = sql.SQL("""
        SELECT id, raw_data, file_name, row_number
        FROM raw_products
        WHERE processed = FALSE
        AND (error_message IS NULL OR error_message = '')
        ORDER BY created_at ASC
        LIMIT %s
        FOR UPDATE SKIP LOCKED
    """)
    
    with conn.cursor() as cursor:
        cursor.execute(query, [batch_size])
        records = cursor.fetchall()
        
        result = []
        for record in records:
            result.append({
                'id': record[0],
                'raw_data': record[1],
                'file_name': record[2],
                'row_number': record[3]
            })
        
        logger.info(f"Retrieved {len(result)} unprocessed records")
        return result

def call_bedrock_claude(product_data: Dict) -> Dict:
    """Call AWS Bedrock Claude model for product enrichment"""
    try:
        # Initialize Bedrock client
        bedrock_client = boto3.client('bedrock-runtime', region_name=BEDROCK_REGION)
        
        # Prepare the prompt
        prompt = create_enrichment_prompt(product_data)
        
        # Prepare request
        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2000,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        }
        
        # Call Bedrock
        response = bedrock_client.invoke_model(
            modelId=BEDROCK_MODEL,
            body=json.dumps(request_body)
        )
        
        # Parse response
        response_body = json.loads(response['body'].read())
        
        if 'content' in response_body and len(response_body['content']) > 0:
            content = response_body['content'][0]['text']
            
            # Extract JSON from response
            try:
                # Find JSON in the response
                start_idx = content.find('{')
                end_idx = content.rfind('}') + 1
                
                if start_idx != -1 and end_idx > start_idx:
                    json_str = content[start_idx:end_idx]
                    enriched_data = json.loads(json_str)
                    
                    # Add metadata
                    enriched_data['processing_timestamp'] = datetime.utcnow().isoformat()
                    enriched_data['bedrock_model'] = BEDROCK_MODEL
                    
                    return enriched_data
                else:
                    raise ValueError("No valid JSON found in response")
                    
            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse JSON from Bedrock response: {str(e)}")
                logger.error(f"Raw response: {content}")
                raise
        else:
            raise ValueError("Empty response from Bedrock")
            
    except Exception as e:
        logger.error(f"Bedrock API call failed: {str(e)}")
        raise

def create_enrichment_prompt(product_data: Dict) -> str:
    """Create enrichment prompt for Claude"""
    prompt = f"""You are a product data expert. Analyze the following product data and return a structured JSON response with enriched information.

RAW PRODUCT DATA:
{json.dumps(product_data, indent=2)}

TASK:
1. Clean and normalize the product name
2. Extract brand, category, color, size if available
3. Clean the description
4. Detect potential duplicates based on product attributes
5. Assign a confidence score (0.0-1.0) for data quality

REQUIREMENTS:
- Return ONLY valid JSON, no additional text
- Use null for missing/unknown values
- Normalize text (proper case, remove special characters)
- Detect duplicates by checking similarity with common product patterns
- Confidence score should reflect data completeness and quality

JSON RESPONSE FORMAT:
{{
    "name_clean": "cleaned product name",
    "brand": "brand name or null",
    "category": "product category or null", 
    "color": "color or null",
    "size": "size or null",
    "price": "price as string or null",
    "description_clean": "cleaned description or null",
    "duplicate_flag": true/false,
    "duplicate_reason": "reason for duplicate flag or null",
    "confidence_score": 0.95,
    "extracted_attributes": {{
        "material": "material or null",
        "style": "style or null",
        "gender": "gender or null"
    }}
}}

Analyze the data and provide the JSON response:"""

    return prompt

def generate_record_hash(enriched_data: Dict) -> str:
    """Generate hash for duplicate detection"""
    key_fields = [
        enriched_data.get('name_clean', ''),
        enriched_data.get('brand', ''),
        enriched_data.get('category', ''),
        enriched_data.get('color', ''),
        enriched_data.get('size', '')
    ]
    
    hash_input = '|'.join(str(field).lower().strip() for field in key_fields)
    return hashlib.md5(hash_input.encode()).hexdigest()

def save_enriched_data(s3_client, enriched_data: Dict, record_id: int):
    """Save enriched data to S3"""
    try:
        # Create folder structure by date
        date_prefix = datetime.now().strftime('%Y/%m/%d')
        key = f"enriched/{date_prefix}/record_{record_id}.json"
        
        # Upload to S3
        s3_client.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=key,
            Body=json.dumps(enriched_data, indent=2),
            ContentType='application/json'
        )
        
        logger.info(f"Saved enriched data to s3://{PROCESSED_BUCKET}/{key}")
        return key
        
    except Exception as e:
        logger.error(f"Failed to save enriched data: {str(e)}")
        raise

def update_record_status(conn, record_id: int, enriched_data: Dict, s3_key: str):
    """Update record status in database"""
    update_query = sql.SQL("""
        UPDATE raw_products 
        SET processed = TRUE,
            processing_timestamp = CURRENT_TIMESTAMP,
            error_message = NULL,
            enriched_data = %s,
            s3_location = %s,
            record_hash = %s
        WHERE id = %s
    """)
    
    with conn.cursor() as cursor:
        cursor.execute(update_query, [
            json.dumps(enriched_data),
            s3_key,
            generate_record_hash(enriched_data),
            record_id
        ])
        conn.commit()
        
        logger.info(f"Updated record {record_id} status to processed")

def mark_record_error(conn, record_id: int, error_message: str):
    """Mark record as failed"""
    update_query = sql.SQL("""
        UPDATE raw_products 
        SET processed = FALSE,
            processing_timestamp = CURRENT_TIMESTAMP,
            error_message = %s
        WHERE id = %s
    """)
    
    with conn.cursor() as cursor:
        cursor.execute(update_query, [error_message, record_id])
        conn.commit()
        
        logger.info(f"Marked record {record_id} as failed: {error_message}")

def process_single_record(conn, s3_client, record: Dict) -> bool:
    """Process a single record"""
    record_id = record['id']
    raw_data = record['raw_data']
    
    try:
        logger.info(f"Processing record {record_id}")
        
        # Call Bedrock for enrichment
        enriched_data = call_bedrock_claude(raw_data)
        
        # Add metadata
        enriched_data['raw_record_id'] = record_id
        enriched_data['file_name'] = record['file_name']
        enriched_data['row_number'] = record['row_number']
        
        # Save to S3
        s3_key = save_enriched_data(s3_client, enriched_data, record_id)
        
        # Update database
        update_record_status(conn, record_id, enriched_data, s3_key)
        
        logger.info(f"Successfully processed record {record_id}")
        return True
        
    except Exception as e:
        error_message = f"Processing failed: {str(e)}"
        logger.error(f"Record {record_id} failed: {error_message}")
        
        # Mark as failed
        mark_record_error(conn, record_id, error_message)
        return False

def lambda_handler(event, context):
    """Main Lambda handler"""
    logger.info(f"Processing Lambda invoked with event: {json.dumps(event)}")
    
    # Initialize clients
    s3_client = boto3.client('s3')
    conn = None
    
    try:
        # Get database connection
        conn = get_db_connection()
        
        # Get unprocessed records
        records = get_unprocessed_records(conn, batch_size=10)
        
        if not records:
            logger.info("No unprocessed records found")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No records to process',
                    'processed_count': 0
                })
            }
        
        # Process records
        processed_count = 0
        failed_count = 0
        
        for record in records:
            if process_single_record(conn, s3_client, record):
                processed_count += 1
            else:
                failed_count += 1
        
        logger.info(f"Processing complete: {processed_count} successful, {failed_count} failed")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Processing complete',
                'processed_count': processed_count,
                'failed_count': failed_count,
                'total_processed': processed_count + failed_count
            })
        }
        
    except Exception as e:
        logger.error(f"Lambda execution failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
    
    finally:
        if conn:
            conn.close()
            logger.info("Database connection closed")

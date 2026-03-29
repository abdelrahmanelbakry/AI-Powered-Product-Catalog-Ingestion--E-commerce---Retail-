import json
import csv
import pandas as pd
import psycopg2
from psycopg2 import sql
import boto3
import os
import logging
from datetime import datetime
from io import StringIO, BytesIO

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
DB_HOST = os.environ.get('DB_HOST')
DB_NAME = os.environ.get('DB_NAME')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')
PROCESSED_BUCKET = os.environ.get('PROCESSED_BUCKET')

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

def create_raw_products_table(conn):
    """Create raw_products table if it doesn't exist"""
    create_table_query = """
    CREATE TABLE IF NOT EXISTS raw_products (
        id SERIAL PRIMARY KEY,
        file_name VARCHAR(255) NOT NULL,
        upload_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        row_number INTEGER NOT NULL,
        raw_data JSONB NOT NULL,
        processed BOOLEAN DEFAULT FALSE,
        processing_timestamp TIMESTAMP,
        error_message TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE INDEX IF NOT EXISTS idx_raw_products_processed ON raw_products(processed);
    CREATE INDEX IF NOT EXISTS idx_raw_products_file_name ON raw_products(file_name);
    """
    
    with conn.cursor() as cursor:
        cursor.execute(create_table_query)
        conn.commit()
        logger.info("raw_products table created or verified")

def parse_csv_file(s3_client, bucket, key):
    """Parse CSV file and return records"""
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        
        # Detect delimiter
        sniffer = csv.Sniffer()
        delimiter = sniffer.sniff(content[:1024]).delimiter
        
        # Parse CSV
        csv_reader = csv.DictReader(StringIO(content), delimiter=delimiter)
        records = list(csv_reader)
        
        logger.info(f"Parsed {len(records)} records from CSV file")
        return records
        
    except Exception as e:
        logger.error(f"Failed to parse CSV file {key}: {str(e)}")
        raise

def parse_excel_file(s3_client, bucket, key):
    """Parse Excel file and return records"""
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read()
        
        # Read Excel file
        df = pd.read_excel(BytesIO(content))
        records = df.to_dict('records')
        
        logger.info(f"Parsed {len(records)} records from Excel file")
        return records
        
    except Exception as e:
        logger.error(f"Failed to parse Excel file {key}: {str(e)}")
        raise

def insert_raw_records(conn, file_name, records):
    """Insert raw records into database"""
    insert_query = sql.SQL("""
        INSERT INTO raw_products (file_name, row_number, raw_data)
        VALUES (%s, %s, %s)
        RETURNING id
    """)
    
    inserted_ids = []
    
    with conn.cursor() as cursor:
        for index, record in enumerate(records, 1):
            try:
                cursor.execute(insert_query, [file_name, index, json.dumps(record)])
                record_id = cursor.fetchone()[0]
                inserted_ids.append(record_id)
            except Exception as e:
                logger.error(f"Failed to insert record {index}: {str(e)}")
                conn.rollback()
                raise
        
        conn.commit()
        logger.info(f"Inserted {len(inserted_ids)} records from {file_name}")
    
    return inserted_ids

def move_to_processed_folder(s3_client, source_bucket, source_key, file_name):
    """Move processed file to processed folder"""
    try:
        destination_key = f"processed/{datetime.now().strftime('%Y/%m/%d')}/{file_name}"
        
        # Copy object
        copy_source = {
            'Bucket': source_bucket,
            'Key': source_key
        }
        s3_client.copy_object(CopySource=copy_source, Bucket=source_bucket, Key=destination_key)
        
        # Delete original
        s3_client.delete_object(Bucket=source_bucket, Key=source_key)
        
        logger.info(f"Moved file from {source_key} to {destination_key}")
        
    except Exception as e:
        logger.error(f"Failed to move file {source_key}: {str(e)}")
        # Don't raise - this is not critical

def lambda_handler(event, context):
    """Main Lambda handler"""
    logger.info(f"Received event: {json.dumps(event)}")
    
    # Extract S3 event information
    try:
        record = event['Records'][0]
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        file_name = key.split('/')[-1]
        
        logger.info(f"Processing file: {file_name} from bucket: {bucket}")
        
    except KeyError as e:
        logger.error(f"Invalid event format: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid event format'})
        }
    
    # Initialize S3 client
    s3_client = boto3.client('s3')
    
    # Get database connection
    conn = None
    try:
        conn = get_db_connection()
        create_raw_products_table(conn)
        
        # Parse file based on extension
        if file_name.lower().endswith('.csv'):
            records = parse_csv_file(s3_client, bucket, key)
        elif file_name.lower().endswith(('.xlsx', '.xls')):
            records = parse_excel_file(s3_client, bucket, key)
        else:
            raise ValueError(f"Unsupported file format: {file_name}")
        
        # Validate records
        if not records:
            raise ValueError("No records found in file")
        
        # Insert records into database
        inserted_ids = insert_raw_records(conn, file_name, records)
        
        # Move file to processed folder
        move_to_processed_folder(s3_client, bucket, key, file_name)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File processed successfully',
                'file_name': file_name,
                'records_processed': len(inserted_ids),
                'inserted_ids': inserted_ids
            })
        }
        
    except Exception as e:
        logger.error(f"Processing failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
    
    finally:
        if conn:
            conn.close()
            logger.info("Database connection closed")

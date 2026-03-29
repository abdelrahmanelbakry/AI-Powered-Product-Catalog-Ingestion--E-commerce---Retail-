"""
Unit Tests for Ingestion Lambda Function
"""

import unittest
from unittest.mock import Mock, patch, MagicMock, mock_open
import json
import csv
import io
import sys
import os

# Import the ingestion lambda function
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lambda', 'ingestion'))
import lambda_function as ingestion_lambda

class TestIngestionLambda(unittest.TestCase):
    """Test cases for the ingestion Lambda function"""

    def setUp(self):
        """Set up test fixtures"""
        self.mock_event = {
            'Records': [{
                's3': {
                    'bucket': {'name': 'test-bucket'},
                    'object': {'key': 'uploads/test_products.csv'}
                }
            }]
        }
        
        self.sample_csv_content = """product_name,price,description,category,brand,color
Nike Air Max 270,$129.99,Comfortable running shoes,Footwear,Nike,Black
Adidas Ultraboost 22,$159.99,High-performance shoes,Footwear,Adidas,White"""
        
        self.expected_records = [
            {
                'product_name': 'Nike Air Max 270',
                'price': '$129.99',
                'description': 'Comfortable running shoes',
                'category': 'Footwear',
                'brand': 'Nike',
                'color': 'Black'
            },
            {
                'product_name': 'Adidas Ultraboost 22',
                'price': '$159.99',
                'description': 'High-performance shoes',
                'category': 'Footwear',
                'brand': 'Adidas',
                'color': 'White'
            }
        ]

    @patch.dict(os.environ, {
        'DB_HOST': 'localhost',
        'DB_NAME': 'test_db',
        'DB_USER': 'test_user',
        'DB_PASSWORD': 'test_password',
        'PROCESSED_BUCKET': 'test-processed-bucket'
    })
    @patch('lambda_function.psycopg2.connect')
    @patch('lambda_function.boto3.client')
    def test_lambda_handler_success(self, mock_boto_client, mock_connect):
        """Test successful Lambda execution"""
        # Mock S3 client
        mock_s3 = Mock()
        mock_boto_client.return_value = mock_s3
        
        # Mock S3 get_object response
        mock_response = {'Body': Mock()}
        mock_response['Body'].read.return_value = self.sample_csv_content.encode('utf-8')
        mock_s3.get_object.return_value = mock_response
        
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchone.return_value = [1]  # Mock record ID
        mock_conn.commit = Mock()
        
        # Mock S3 copy_object and delete_object
        mock_s3.copy_object = Mock()
        mock_s3.delete_object = Mock()
        
        # Execute Lambda handler
        result = ingestion_lambda.lambda_handler(self.mock_event, Mock())
        
        # Verify results
        self.assertEqual(result['statusCode'], 200)
        response_body = json.loads(result['body'])
        self.assertEqual(response_body['file_name'], 'test_products.csv')
        self.assertEqual(response_body['records_processed'], 2)
        self.assertIn('inserted_ids', response_body)
        
        # Verify S3 operations
        mock_s3.get_object.assert_called_once_with(
            Bucket='test-bucket',
            Key='uploads/test_products.csv'
        )
        
        # Verify database operations
        mock_connect.assert_called_once()
        mock_cursor.execute.assert_called()
        mock_conn.commit.assert_called()

    @patch.dict(os.environ, {
        'DB_HOST': 'localhost',
        'DB_NAME': 'test_db',
        'DB_USER': 'test_user',
        'DB_PASSWORD': 'test_password',
        'PROCESSED_BUCKET': 'test-processed-bucket'
    })
    @patch('lambda_function.boto3.client')
    def test_parse_csv_file(self, mock_boto_client):
        """Test CSV file parsing"""
        # Mock S3 client
        mock_s3 = Mock()
        mock_boto_client.return_value = mock_s3
        
        # Mock S3 get_object response
        mock_response = {'Body': Mock()}
        mock_response['Body'].read.return_value = self.sample_csv_content.encode('utf-8')
        mock_s3.get_object.return_value = mock_response
        
        # Test CSV parsing
        records = ingestion_lambda.parse_csv_file(mock_s3, 'test-bucket', 'test-key')
        
        # Verify results
        self.assertEqual(len(records), 2)
        self.assertEqual(records[0]['product_name'], 'Nike Air Max 270')
        self.assertEqual(records[1]['brand'], 'Adidas')

    @patch.dict(os.environ, {
        'DB_HOST': 'localhost',
        'DB_NAME': 'test_db',
        'DB_USER': 'test_user',
        'DB_PASSWORD': 'test_password',
        'PROCESSED_BUCKET': 'test-processed-bucket'
    })
    @patch('lambda_function.psycopg2.connect')
    def test_insert_raw_records(self, mock_connect):
        """Test database record insertion"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_cursor.fetchone.return_value = [1]  # Mock record ID
        mock_conn.commit = Mock()
        
        # Test record insertion
        inserted_ids = ingestion_lambda.insert_raw_records(
            mock_conn, 
            'test_file.csv', 
            self.expected_records
        )
        
        # Verify results
        self.assertEqual(len(inserted_ids), 2)
        self.assertEqual(inserted_ids, [1, 1])  # Both return mock ID 1
        
        # Verify database operations
        self.assertEqual(mock_cursor.execute.call_count, 2)
        mock_conn.commit.assert_called_once()

    @patch.dict(os.environ, {
        'DB_HOST': 'localhost',
        'DB_NAME': 'test_db',
        'DB_USER': 'test_user',
        'DB_PASSWORD': 'test_password',
        'PROCESSED_BUCKET': 'test-processed-bucket'
    })
    @patch('lambda_function.psycopg2.connect')
    @patch('lambda_function.boto3.client')
    def test_create_raw_products_table(self, mock_boto_client, mock_connect):
        """Test table creation"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_conn.commit = Mock()
        
        # Test table creation
        ingestion_lambda.create_raw_products_table(mock_conn)
        
        # Verify SQL execution
        mock_cursor.execute.assert_called()
        mock_conn.commit.assert_called()

    @patch('lambda_function.boto3.client')
    def test_move_to_processed_folder(self, mock_boto_client):
        """Test file movement to processed folder"""
        # Mock S3 client
        mock_s3 = Mock()
        mock_boto_client.return_value = mock_s3
        
        # Test file movement
        ingestion_lambda.move_to_processed_folder(
            mock_s3, 
            'source-bucket', 
            'uploads/test.csv', 
            'test.csv'
        )
        
        # Verify S3 operations
        mock_s3.copy_object.assert_called_once()
        mock_s3.delete_object.assert_called_once()

    def test_lambda_handler_invalid_event(self):
        """Test Lambda handler with invalid event"""
        invalid_event = {'invalid': 'event'}
        
        result = ingestion_lambda.lambda_handler(invalid_event, Mock())
        
        self.assertEqual(result['statusCode'], 400)
        response_body = json.loads(result['body'])
        self.assertIn('error', response_body)

    @patch.dict(os.environ, {}, clear=True)
    def test_lambda_handler_missing_env_vars(self):
        """Test Lambda handler with missing environment variables"""
        with self.assertRaises(Exception):
            ingestion_lambda.lambda_handler(self.mock_event, Mock())

    @patch.dict(os.environ, {
        'DB_HOST': 'localhost',
        'DB_NAME': 'test_db',
        'DB_USER': 'test_user',
        'DB_PASSWORD': 'test_password',
        'PROCESSED_BUCKET': 'test-processed-bucket'
    })
    @patch('lambda_function.boto3.client')
    def test_unsupported_file_format(self, mock_boto_client):
        """Test handling of unsupported file formats"""
        # Create event with unsupported file
        unsupported_event = {
            'Records': [{
                's3': {
                    'bucket': {'name': 'test-bucket'},
                    'object': {'key': 'uploads/test_file.txt'}
                }
            }]
        }
        
        result = ingestion_lambda.lambda_handler(unsupported_event, Mock())
        
        self.assertEqual(result['statusCode'], 500)
        response_body = json.loads(result['body'])
        self.assertIn('error', response_body)

    @patch.dict(os.environ, {
        'DB_HOST': 'localhost',
        'DB_NAME': 'test_db',
        'DB_USER': 'test_user',
        'DB_PASSWORD': 'test_password',
        'PROCESSED_BUCKET': 'test-processed-bucket'
    })
    @patch('lambda_function.psycopg2.connect')
    @patch('lambda_function.boto3.client')
    def test_database_error_handling(self, mock_boto_client, mock_connect):
        """Test database error handling"""
        # Mock S3 client
        mock_s3 = Mock()
        mock_boto_client.return_value = mock_s3
        
        # Mock S3 get_object response
        mock_response = {'Body': Mock()}
        mock_response['Body'].read.return_value = self.sample_csv_content.encode('utf-8')
        mock_s3.get_object.return_value = mock_response
        
        # Mock database connection error
        mock_connect.side_effect = Exception("Database connection failed")
        
        result = ingestion_lambda.lambda_handler(self.mock_event, Mock())
        
        self.assertEqual(result['statusCode'], 500)
        response_body = json.loads(result['body'])
        self.assertIn('error', response_body)

    @patch.dict(os.environ, {
        'DB_HOST': 'localhost',
        'DB_NAME': 'test_db',
        'DB_USER': 'test_user',
        'DB_PASSWORD': 'test_password',
        'PROCESSED_BUCKET': 'test-processed-bucket'
    })
    @patch('lambda_function.psycopg2.connect')
    @patch('lambda_function.boto3.client')
    def test_empty_file_handling(self, mock_boto_client, mock_connect):
        """Test handling of empty files"""
        # Mock S3 client
        mock_s3 = Mock()
        mock_boto_client.return_value = mock_s3
        
        # Mock S3 get_object response with empty content
        mock_response = {'Body': Mock()}
        mock_response['Body'].read.return_value = b''
        mock_s3.get_object.return_value = mock_response
        
        # Mock database connection
        mock_conn = Mock()
        mock_connect.return_value = mock_conn
        
        result = ingestion_lambda.lambda_handler(self.mock_event, Mock())
        
        self.assertEqual(result['statusCode'], 500)
        response_body = json.loads(result['body'])
        self.assertIn('error', response_body)


if __name__ == '__main__':
    unittest.main()

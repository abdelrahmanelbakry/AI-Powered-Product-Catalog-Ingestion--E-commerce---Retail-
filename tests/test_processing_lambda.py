"""
Unit Tests for Processing Lambda Function
"""

import unittest
from unittest.mock import Mock, patch, MagicMock
import json
import sys
import os

# Import the processing lambda function
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lambda', 'processing'))
import lambda_function as processing_lambda

class TestProcessingLambda(unittest.TestCase):
    """Test cases for the processing Lambda function"""

    def setUp(self):
        """Set up test fixtures"""
        self.mock_event = {}
        
        self.sample_raw_data = {
            'product_name': 'Nike Air Max 270 Running Shoes',
            'price': '$129.99',
            'description': 'Comfortable running shoes with air cushioning'
        }
        
        self.sample_enriched_data = {
            'name_clean': 'Nike Air Max 270 Running Shoes',
            'brand': 'Nike',
            'category': 'Footwear',
            'color': None,
            'size': None,
            'price': '$129.99',
            'description_clean': 'Comfortable running shoes with air cushioning technology',
            'duplicate_flag': False,
            'duplicate_reason': None,
            'confidence_score': 0.85,
            'extracted_attributes': {
                'material': None,
                'style': 'Running',
                'gender': 'Unisex',
                'season': None
            }
        }
        
        self.mock_db_records = [
            {
                'id': 1,
                'raw_data': self.sample_raw_data,
                'file_name': 'test_products.csv',
                'row_number': 1
            },
            {
                'id': 2,
                'raw_data': {'product_name': 'Adidas Ultraboost', 'price': '$159.99'},
                'file_name': 'test_products.csv',
                'row_number': 2
            }
        ]

    @patch.dict(os.environ, {
        'DB_HOST': 'localhost',
        'DB_NAME': 'test_db',
        'DB_USER': 'test_user',
        'DB_PASSWORD': 'test_password',
        'PROCESSED_BUCKET': 'test-processed-bucket',
        'BEDROCK_REGION': 'us-east-1',
        'BEDROCK_MODEL': 'anthropic.claude-v2'
    })
    @patch('lambda_function.psycopg2.connect')
    @patch('lambda_function.boto3.client')
    def test_lambda_handler_success(self, mock_boto_client, mock_connect):
        """Test successful Lambda execution"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = [
            (1, json.dumps(self.sample_raw_data), 'test.csv', 1)
        ]
        mock_conn.commit = Mock()
        
        # Mock Bedrock response
        mock_bedrock = Mock()
        mock_boto_client.return_value = mock_bedrock
        mock_response = {'body': Mock()}
        mock_response['body'].read.return_value = json.dumps({
            'content': [{'text': json.dumps(self.sample_enriched_data)}]
        }).encode('utf-8')
        mock_bedrock.invoke_model.return_value = mock_response
        
        # Mock S3 client
        mock_s3 = Mock()
        mock_boto_client.side_effect = [mock_bedrock, mock_s3]
        mock_s3.put_object = Mock()
        
        # Execute Lambda handler
        result = processing_lambda.lambda_handler(self.mock_event, Mock())
        
        # Verify results
        self.assertEqual(result['statusCode'], 200)
        response_body = json.loads(result['body'])
        self.assertEqual(response_body['processed_count'], 1)
        self.assertEqual(response_body['failed_count'], 0)

    @patch.dict(os.environ, {
        'DB_HOST': 'localhost',
        'DB_NAME': 'test_db',
        'DB_USER': 'test_user',
        'DB_PASSWORD': 'test_password',
        'PROCESSED_BUCKET': 'test-processed-bucket',
        'BEDROCK_REGION': 'us-east-1',
        'BEDROCK_MODEL': 'anthropic.claude-v2'
    })
    @patch('lambda_function.psycopg2.connect')
    def test_get_unprocessed_records(self, mock_connect):
        """Test fetching unprocessed records"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = [
            (1, json.dumps(self.sample_raw_data), 'test.csv', 1),
            (2, json.dumps({'product_name': 'Adidas'}), 'test.csv', 2)
        ]
        
        # Test record fetching
        records = processing_lambda.get_unprocessed_records(mock_conn, batch_size=10)
        
        # Verify results
        self.assertEqual(len(records), 2)
        self.assertEqual(records[0]['id'], 1)
        self.assertEqual(records[0]['file_name'], 'test.csv')
        self.assertEqual(records[1]['id'], 2)

    @patch.dict(os.environ, {
        'BEDROCK_REGION': 'us-east-1',
        'BEDROCK_MODEL': 'anthropic.claude-v2'
    })
    @patch('lambda_function.boto3.client')
    def test_call_bedrock_claude(self, mock_boto_client):
        """Test Bedrock API call"""
        # Mock Bedrock client and response
        mock_bedrock = Mock()
        mock_boto_client.return_value = mock_bedrock
        mock_response = {'body': Mock()}
        mock_response['body'].read.return_value = json.dumps({
            'content': [{'text': json.dumps(self.sample_enriched_data)}]
        }).encode('utf-8')
        mock_bedrock.invoke_model.return_value = mock_response
        
        # Test Bedrock call
        result = processing_lambda.call_bedrock_claude(self.sample_raw_data)
        
        # Verify results
        self.assertEqual(result['name_clean'], 'Nike Air Max 270 Running Shoes')
        self.assertEqual(result['brand'], 'Nike')
        self.assertEqual(result['confidence_score'], 0.85)
        self.assertIn('processing_timestamp', result)
        self.assertEqual(result['bedrock_model'], 'anthropic.claude-v2')

    @patch.dict(os.environ, {
        'BEDROCK_REGION': 'us-east-1',
        'BEDROCK_MODEL': 'anthropic.claude-v2'
    })
    @patch('lambda_function.boto3.client')
    def test_call_bedrock_claude_invalid_response(self, mock_boto_client):
        """Test Bedrock API call with invalid response"""
        # Mock Bedrock client and invalid response
        mock_bedrock = Mock()
        mock_boto_client.return_value = mock_bedrock
        mock_response = {'body': Mock()}
        mock_response['body'].read.return_value = b'invalid response'
        mock_bedrock.invoke_model.return_value = mock_response
        
        # Test should raise exception
        with self.assertRaises(Exception):
            processing_lambda.call_bedrock_claude(self.sample_raw_data)

    def test_create_enrichment_prompt(self):
        """Test enrichment prompt creation"""
        prompt = processing_lambda.create_enrichment_prompt(self.sample_raw_data)
        
        # Verify prompt contains expected elements
        self.assertIn('product data expert', prompt.lower())
        self.assertIn('json response', prompt.lower())
        self.assertIn('confidence score', prompt.lower())
        self.assertIn('duplicate detection', prompt.lower())
        self.assertIn(json.dumps(self.sample_raw_data), prompt)

    @patch('lambda_function.boto3.client')
    def test_save_enriched_data(self, mock_boto_client):
        """Test saving enriched data to S3"""
        # Mock S3 client
        mock_s3 = Mock()
        mock_boto_client.return_value = mock_s3
        mock_s3.put_object = Mock()
        
        # Test data saving
        s3_key = processing_lambda.save_enriched_data(
            mock_s3, 
            self.sample_enriched_data, 
            1
        )
        
        # Verify S3 operation
        mock_s3.put_object.assert_called_once()
        self.assertIn('enriched/', s3_key)
        self.assertIn('record_1', s3_key)

    @patch('lambda_function.psycopg2.connect')
    def test_update_record_status(self, mock_connect):
        """Test updating record status in database"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_conn.commit = Mock()
        
        # Test status update
        processing_lambda.update_record_status(
            mock_conn, 
            1, 
            self.sample_enriched_data, 
            'test-key'
        )
        
        # Verify database operation
        mock_cursor.execute.assert_called_once()
        mock_conn.commit.assert_called_once()

    @patch('lambda_function.psycopg2.connect')
    def test_mark_record_error(self, mock_connect):
        """Test marking record as failed"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_conn.commit = Mock()
        
        # Test error marking
        processing_lambda.mark_record_error(
            mock_conn, 
            1, 
            'Test error message'
        )
        
        # Verify database operation
        mock_cursor.execute.assert_called_once()
        mock_conn.commit.assert_called_once()

    @patch('lambda_function.psycopg2.connect')
    @patch('lambda_function.boto3.client')
    def test_process_single_record_success(self, mock_boto_client, mock_connect):
        """Test successful processing of a single record"""
        record = {
            'id': 1,
            'raw_data': self.sample_raw_data,
            'file_name': 'test.csv',
            'row_number': 1
        }
        
        # Mock database connection
        mock_conn = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.commit = Mock()
        
        # Mock Bedrock response
        mock_bedrock = Mock()
        mock_boto_client.return_value = mock_bedrock
        mock_response = {'body': Mock()}
        mock_response['body'].read.return_value = json.dumps({
            'content': [{'text': json.dumps(self.sample_enriched_data)}]
        }).encode('utf-8')
        mock_bedrock.invoke_model.return_value = mock_response
        
        # Mock S3 client
        mock_s3 = Mock()
        mock_boto_client.side_effect = [mock_bedrock, mock_s3]
        mock_s3.put_object = Mock()
        
        # Test record processing
        result = processing_lambda.process_single_record(mock_conn, mock_s3, record)
        
        # Verify success
        self.assertTrue(result)

    @patch('lambda_function.psycopg2.connect')
    @patch('lambda_function.boto3.client')
    def test_process_single_record_failure(self, mock_boto_client, mock_connect):
        """Test failed processing of a single record"""
        record = {
            'id': 1,
            'raw_data': self.sample_raw_data,
            'file_name': 'test.csv',
            'row_number': 1
        }
        
        # Mock database connection
        mock_conn = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.commit = Mock()
        
        # Mock Bedrock failure
        mock_bedrock = Mock()
        mock_boto_client.return_value = mock_bedrock
        mock_bedrock.invoke_model.side_effect = Exception("Bedrock API error")
        
        # Test record processing
        result = processing_lambda.process_single_record(mock_conn, mock_bedrock, record)
        
        # Verify failure
        self.assertFalse(result)

    def test_generate_record_hash(self):
        """Test record hash generation"""
        hash1 = processing_lambda.generate_record_hash(self.sample_enriched_data)
        hash2 = processing_lambda.generate_record_hash(self.sample_enriched_data)
        
        # Verify consistency
        self.assertEqual(hash1, hash2)
        self.assertEqual(len(hash1), 32)  # MD5 hash length

    @patch.dict(os.environ, {
        'DB_HOST': 'localhost',
        'DB_NAME': 'test_db',
        'DB_USER': 'test_user',
        'DB_PASSWORD': 'test_password',
        'PROCESSED_BUCKET': 'test-processed-bucket',
        'BEDROCK_REGION': 'us-east-1',
        'BEDROCK_MODEL': 'anthropic.claude-v2'
    })
    @patch('lambda_function.psycopg2.connect')
    @patch('lambda_function.boto3.client')
    def test_lambda_handler_no_records(self, mock_boto_client, mock_connect):
        """Test Lambda handler with no records to process"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = []  # No records
        
        # Execute Lambda handler
        result = processing_lambda.lambda_handler(self.mock_event, Mock())
        
        # Verify results
        self.assertEqual(result['statusCode'], 200)
        response_body = json.loads(result['body'])
        self.assertEqual(response_body['processed_count'], 0)
        self.assertIn('No records to process', response_body['message'])

    @patch.dict(os.environ, {}, clear=True)
    def test_lambda_handler_missing_env_vars(self):
        """Test Lambda handler with missing environment variables"""
        with self.assertRaises(Exception):
            processing_lambda.lambda_handler(self.mock_event, Mock())

    @patch.dict(os.environ, {
        'DB_HOST': 'localhost',
        'DB_NAME': 'test_db',
        'DB_USER': 'test_user',
        'DB_PASSWORD': 'test_password',
        'PROCESSED_BUCKET': 'test-processed-bucket',
        'BEDROCK_REGION': 'us-east-1',
        'BEDROCK_MODEL': 'anthropic.claude-v2'
    })
    @patch('lambda_function.psycopg2.connect')
    @patch('lambda_function.boto3.client')
    def test_lambda_handler_mixed_results(self, mock_boto_client, mock_connect):
        """Test Lambda handler with mixed success/failure results"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = [
            (1, json.dumps(self.sample_raw_data), 'test.csv', 1),
            (2, json.dumps({'product_name': 'Adidas'}), 'test.csv', 2)
        ]
        mock_conn.commit = Mock()
        
        # Mock Bedrock - success for first, failure for second
        mock_bedrock = Mock()
        mock_boto_client.return_value = mock_bedrock
        
        def mock_invoke_model(*args, **kwargs):
            if 'test' in str(args):
                return {'body': Mock(read=Mock(return_value=json.dumps({
                    'content': [{'text': json.dumps(self.sample_enriched_data)}]
                }).encode('utf-8')))}
            else:
                raise Exception("Bedrock error")
        
        mock_bedrock.invoke_model.side_effect = mock_invoke_model
        
        # Mock S3 client
        mock_s3 = Mock()
        mock_boto_client.side_effect = [mock_bedrock, mock_s3]
        mock_s3.put_object = Mock()
        
        # Execute Lambda handler
        result = processing_lambda.lambda_handler(self.mock_event, Mock())
        
        # Verify mixed results
        self.assertEqual(result['statusCode'], 200)
        response_body = json.loads(result['body'])
        self.assertEqual(response_body['processed_count'], 1)
        self.assertEqual(response_body['failed_count'], 1)


if __name__ == '__main__':
    unittest.main()

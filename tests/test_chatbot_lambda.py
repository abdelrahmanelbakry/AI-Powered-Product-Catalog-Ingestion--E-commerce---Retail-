"""
Unit Tests for ChatBot Lambda Function
"""

import unittest
from unittest.mock import Mock, patch, MagicMock
import json
import sys
import os

# Add the chatbot lambda directory to the path for testing
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lambda', 'chatbot'))
import lambda_function as chatbot_lambda

class TestChatBotLambda(unittest.TestCase):
    """Test cases for the ChatBot Lambda function"""

    def setUp(self):
        """Set up test fixtures"""
        self.mock_event = {
            'body': json.dumps({
                'message': 'Check for missing product names',
                'session_id': 'test-session'
            })
        }
        
        self.sample_db_records = [
            {'id': 1, 'product_name': 'Nike Air Max', 'brand': 'Nike', 'category': 'Footwear', 'price': '$129.99'},
            {'id': 2, 'product_name': '', 'brand': 'Adidas', 'category': 'Footwear', 'price': '$159.99'},
            {'id': 3, 'product_name': 'Levis Jeans', 'brand': '', 'category': 'Clothing', 'price': '$89.99'}
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
    @patch('lambda_function.s3_client')
    def test_lambda_handler_success(self, mock_s3, mock_connect):
        """Test successful Lambda handler execution"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = self.sample_db_records[1:2]  # Return records with missing names
        mock_conn.close = Mock()
        
        # Mock S3 client
        mock_s3.put_object = Mock()
        
        # Execute Lambda handler
        result = chatbot_lambda.lambda_handler(self.mock_event, Mock())
        
        # Verify results
        self.assertEqual(result['statusCode'], 200)
        response_body = json.loads(result['body'])
        self.assertEqual(response_body['type'], 'quality_report')
        self.assertIn('content', response_body)
        self.assertIn('metrics', response_body)

    def test_lambda_handler_missing_message(self):
        """Test Lambda handler with missing message"""
        invalid_event = {
            'body': json.dumps({
                'session_id': 'test-session'
            })
        }
        
        result = chatbot_lambda.lambda_handler(invalid_event, Mock())
        
        self.assertEqual(result['statusCode'], 400)
        response_body = json.loads(result['body'])
        self.assertIn('error', response_body)

    def test_lambda_handler_invalid_json(self):
        """Test Lambda handler with invalid JSON"""
        invalid_event = {
            'body': 'invalid json'
        }
        
        result = chatbot_lambda.lambda_handler(invalid_event, Mock())
        
        self.assertEqual(result['statusCode'], 500)
        response_body = json.loads(result['body'])
        self.assertIn('error', response_body)

    @patch.dict(os.environ, {}, clear=True)
    def test_lambda_handler_missing_env_vars(self):
        """Test Lambda handler with missing environment variables"""
        with self.assertRaises(KeyError):
            chatbot_lambda.lambda_handler(self.mock_event, Mock())

    def test_parse_data_quality_rule_null_check(self):
        """Test parsing null check rule"""
        rule = chatbot_lambda.parse_data_quality_rule("Check for missing product names")
        
        self.assertIsNotNone(rule)
        self.assertEqual(rule['type'], 'null_check')
        self.assertEqual(rule['match'][0], 'name')
        self.assertIn('missing product names', rule['original_input'])

    def test_parse_data_quality_rule_price_range(self):
        """Test parsing price range rule"""
        rule = chatbot_lambda.parse_data_quality_rule("Price should be between $50 and $500")
        
        self.assertIsNotNone(rule)
        self.assertEqual(rule['type'], 'price_range')
        self.assertEqual(rule['match'][1], '50')
        self.assertEqual(rule['match'][2], '500')

    def test_parse_data_quality_rule_category_validation(self):
        """Test parsing category validation rule"""
        rule = chatbot_lambda.parse_data_quality_rule("Category should be one of Footwear, Clothing, Electronics")
        
        self.assertIsNotNone(rule)
        self.assertEqual(rule['type'], 'category_validation')
        self.assertIn('Footwear', rule['match'][1])

    def test_parse_data_quality_rule_duplicate_detection(self):
        """Test parsing duplicate detection rule"""
        rule = chatbot_lambda.parse_data_quality_rule("No duplicate products")
        
        self.assertIsNotNone(rule)
        self.assertEqual(rule['type'], 'duplicate_detection')

    def test_parse_data_quality_rule_invalid(self):
        """Test parsing invalid rule"""
        rule = chatbot_lambda.parse_data_quality_rule("This is not a valid rule")
        
        self.assertIsNone(rule)

    @patch('lambda_function.psycopg2.connect')
    def test_execute_rule_by_type_null_check(self, mock_connect):
        """Test executing null check rule"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = self.sample_db_records[1:2]
        
        rule = {
            'type': 'null_check',
            'match': ['name'],
            'original_input': 'Check for missing product names'
        }
        
        results = chatbot_lambda.execute_rule_by_type(mock_cursor, rule)
        
        # Verify SQL execution
        mock_cursor.execute.assert_called_once()
        self.assertIn('WHERE product_name IS NULL', mock_cursor.execute.call_args[0][0])

    @patch('lambda_function.psycopg2.connect')
    def test_execute_rule_by_type_price_range(self, mock_connect):
        """Test executing price range rule"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = []
        
        rule = {
            'type': 'price_range',
            'match': ['price', '50', '500'],
            'original_input': 'Price should be between $50 and $500'
        }
        
        results = chatbot_lambda.execute_rule_by_type(mock_cursor, rule)
        
        # Verify SQL execution
        mock_cursor.execute.assert_called_once()
        self.assertIn('WHERE price IS NOT NULL', mock_cursor.execute.call_args[0][0])

    @patch('lambda_function.psycopg2.connect')
    def test_execute_rule_by_type_category_validation(self, mock_connect):
        """Test executing category validation rule"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = []
        
        rule = {
            'type': 'category_validation',
            'match': ['category', 'Footwear, Clothing, Electronics'],
            'original_input': 'Category should be one of Footwear, Clothing, Electronics'
        }
        
        results = chatbot_lambda.execute_rule_by_type(mock_cursor, rule)
        
        # Verify SQL execution
        mock_cursor.execute.assert_called_once()
        self.assertIn('WHERE category NOT IN', mock_cursor.execute.call_args[0][0])

    @patch('lambda_function.get_total_record_count')
    def test_generate_quality_report(self, mock_get_count):
        """Test quality report generation"""
        mock_get_count.return_value = 100
        
        rule = {
            'type': 'null_check',
            'match': ['name'],
            'original_input': 'Check for missing product names'
        }
        
        results = [
            {'id': 2, 'field_value': '', 'field_name': 'product_name'},
            {'id': 5, 'field_value': 'NULL', 'field_name': 'product_name'}
        ]
        
        report = chatbot_lambda.generate_quality_report(rule, results)
        
        # Verify report structure
        self.assertIn('id', report)
        self.assertIn('rule', report)
        self.assertIn('metrics', report)
        self.assertIn('issues', report)
        self.assertIn('recommendations', report)
        
        # Verify metrics
        self.assertEqual(report['metrics']['total_records'], 100)
        self.assertEqual(report['metrics']['failed_records'], 2)
        self.assertEqual(report['metrics']['passed_records'], 98)
        self.assertEqual(report['metrics']['pass_rate'], 98.0)

    def test_format_issue_description(self):
        """Test issue description formatting"""
        rule = {'type': 'null_check'}
        result = {'field_name': 'product_name', 'field_value': ''}
        
        description = chatbot_lambda.format_issue_description(rule, result)
        
        self.assertIn('product_name is null or empty', description)

    def test_generate_recommendations(self):
        """Test recommendation generation"""
        rule = {'type': 'null_check'}
        
        # Test with no failures
        recommendations = chatbot_lambda.generate_recommendations(rule, 0, 100)
        self.assertIn('Excellent data quality', recommendations[0])
        
        # Test with failures
        recommendations = chatbot_lambda.generate_recommendations(rule, 10, 90)
        self.assertIn('Address 10 data quality issues', recommendations[0])

    @patch('lambda_function.s3_client')
    def test_save_report_to_s3(self, mock_s3):
        """Test saving report to S3"""
        report = {
            'id': 'test_report',
            'rule': 'test rule',
            'metrics': {'total_records': 100}
        }
        
        chatbot_lambda.save_report_to_s3(report)
        
        # Verify S3 put_object was called
        mock_s3.put_object.assert_called_once()
        call_args = mock_s3.put_object.call_args
        self.assertEqual(call_args[1]['Bucket'], 'test-processed-bucket')
        self.assertIn('quality-reports/test_report.json', call_args[1]['Key'])

    def test_is_data_query(self):
        """Test data query detection"""
        # Test positive cases
        self.assertTrue(chatbot_lambda.is_data_query("How many products do we have?"))
        self.assertTrue(chatbot_lambda.is_data_query("Show me all footwear products"))
        self.assertTrue(chatbot_lambda.is_data_query("List products by category"))
        
        # Test negative cases
        self.assertFalse(chatbot_lambda.is_data_query("Check for missing names"))
        self.assertFalse(chatbot_lambda.is_data_query("Price should be between $50 and $500"))
        self.assertFalse(chatbot_lambda.is_data_query("Hello, how are you?"))

    @patch('lambda_function.psycopg2.connect')
    def test_handle_data_query_count(self, mock_connect):
        """Test handling count query"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = [{'total': 150}]
        mock_conn.close = Mock()
        
        result = chatbot_lambda.handle_data_query("How many products do we have?")
        
        # Verify result
        self.assertEqual(result['type'], 'data_query')
        self.assertIn('150 total products', result['content'])

    @patch('lambda_function.psycopg2.connect')
    def test_handle_data_query_list(self, mock_connect):
        """Test handling list query"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = self.sample_db_records[:3]
        mock_conn.close = Mock()
        
        result = chatbot_lambda.handle_data_query("Show me all products")
        
        # Verify result
        self.assertEqual(result['type'], 'data_query')
        self.assertIn('Product List', result['content'])

    def test_handle_general_conversation(self):
        """Test handling general conversation"""
        result = chatbot_lambda.handle_general_conversation("Hello, what can you do?")
        
        # Verify result
        self.assertEqual(result['type'], 'general')
        self.assertIn('I can help you analyze your product catalog data', result['content'])
        self.assertIn('Data Queries', result['content'])
        self.assertIn('Data Quality Rules', result['content'])

    def test_format_query_response_empty(self):
        """Test formatting empty query response"""
        result = chatbot_lambda.format_query_response([])
        
        self.assertIn('No data found', result)

    def test_format_query_response_with_data(self):
        """Test formatting query response with data"""
        result = [{'total': 100}]
        
        formatted = chatbot_lambda.format_query_response(result)
        
        self.assertIn('100 total products', formatted)

    def test_format_quality_response(self):
        """Test formatting quality response"""
        rule = {
            'type': 'null_check',
            'original_input': 'Check for missing product names'
        }
        
        report = {
            'recommendations': ['🎉 Excellent data quality!'],
            'metrics': {
                'total_records': 100,
                'passed_records': 95,
                'failed_records': 5,
                'pass_rate': 95.0
            },
            'issues': [
                {'id': 2, 'issue': 'product_name is null or empty'},
                {'id': 5, 'issue': 'product_name is null or empty'}
            ]
        }
        
        response = chatbot_lambda.format_quality_response(rule, report)
        
        self.assertIn('95.0%', response)
        self.assertIn('Record 2: product_name is null or empty', response)
        self.assertIn('🎉 Excellent data quality!', response)

    @patch('lambda_function.psycopg2.connect')
    @patch('lambda_function.s3_client')
    def test_execute_data_quality_rule_success(self, mock_s3, mock_connect):
        """Test successful data quality rule execution"""
        # Mock database connection and cursor
        mock_conn = Mock()
        mock_cursor = Mock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        mock_cursor.fetchall.return_value = []
        mock_conn.close = Mock()
        
        # Mock S3
        mock_s3.put_object = Mock()
        
        rule = {
            'type': 'null_check',
            'match': ['name'],
            'original_input': 'Check for missing product names'
        }
        
        with patch('lambda_function.get_total_record_count', return_value=100):
            result = chatbot_lambda.execute_data_quality_rule(rule)
        
        # Verify result
        self.assertEqual(result['type'], 'quality_report')
        self.assertIn('content', result)
        self.assertIn('metrics', result)
        self.assertIn('report_id', result)

    @patch('lambda_function.psycopg2.connect')
    def test_execute_data_quality_rule_error(self, mock_connect):
        """Test data quality rule execution with error"""
        # Mock database connection error
        mock_connect.side_effect = Exception("Database connection failed")
        
        rule = {
            'type': 'null_check',
            'match': ['name'],
            'original_input': 'Check for missing product names'
        }
        
        result = chatbot_lambda.execute_data_quality_rule(rule)
        
        # Verify error handling
        self.assertEqual(result['type'], 'error')
        self.assertIn('could not execute', result['content'])


if __name__ == '__main__':
    unittest.main()

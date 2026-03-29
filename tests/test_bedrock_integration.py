"""
Unit Tests for Bedrock Integration
"""

import unittest
from unittest.mock import Mock, patch, MagicMock
import json
import sys
import os

# Add the processing lambda directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lambda', 'processing'))
import lambda_function as processing_lambda

class TestBedrockIntegration(unittest.TestCase):
    """Test cases for Bedrock AI integration"""

    def setUp(self):
        """Set up test fixtures"""
        self.sample_product_data = {
            'product_name': 'Nike Air Max 270 Running Shoes - Black/White Size 10',
            'price': '$129.99',
            'description': 'Comfortable running shoes with air cushioning technology',
            'category': 'Footwear',
            'brand': 'Nike',
            'color': 'Black/White',
            'size': '10'
        }
        
        self.expected_enriched_data = {
            'name_clean': 'Nike Air Max 270 Running Shoes',
            'brand': 'Nike',
            'category': 'Footwear',
            'color': 'Black/White',
            'size': '10',
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

    @patch.dict(os.environ, {
        'BEDROCK_REGION': 'us-east-1',
        'BEDROCK_MODEL': 'anthropic.claude-v2'
    })
    @patch('lambda_function.boto3.client')
    def test_bedrock_api_call_success(self, mock_boto_client):
        """Test successful Bedrock API call"""
        # Mock Bedrock client and response
        mock_bedrock = Mock()
        mock_boto_client.return_value = mock_bedrock
        
        mock_response = {'body': Mock()}
        mock_response['body'].read.return_value = json.dumps({
            'content': [{'text': json.dumps(self.expected_enriched_data)}]
        }).encode('utf-8')
        mock_bedrock.invoke_model.return_value = mock_response
        
        # Test Bedrock call
        result = processing_lambda.call_bedrock_claude(self.sample_product_data)
        
        # Verify API call
        mock_bedrock.invoke_model.assert_called_once()
        call_args = mock_bedrock.invoke_model.call_args
        self.assertEqual(call_args[1]['modelId'], 'anthropic.claude-v2')
        
        # Verify request body structure
        request_body = json.loads(call_args[1]['body'])
        self.assertEqual(request_body['anthropic_version'], 'bedrock-2023-05-31')
        self.assertEqual(request_body['max_tokens'], 2000)
        self.assertIn('messages', request_body)
        self.assertEqual(len(request_body['messages']), 1)
        
        # Verify response
        self.assertEqual(result['name_clean'], 'Nike Air Max 270 Running Shoes')
        self.assertEqual(result['brand'], 'Nike')
        self.assertEqual(result['confidence_score'], 0.85)

    @patch.dict(os.environ, {
        'BEDROCK_REGION': 'us-east-1',
        'BEDROCK_MODEL': 'anthropic.claude-v2'
    })
    @patch('lambda_function.boto3.client')
    def test_bedrock_api_call_throttling(self, mock_boto_client):
        """Test Bedrock API call with throttling"""
        # Mock Bedrock client with throttling error
        mock_bedrock = Mock()
        mock_boto_client.return_value = mock_bedrock
        
        from botocore.exceptions import ClientError
        throttling_error = ClientError(
            {'Error': {'Code': 'ThrottlingException', 'Message': 'Rate limit exceeded'}},
            'InvokeModel'
        )
        mock_bedrock.invoke_model.side_effect = throttling_error
        
        # Test should raise exception
        with self.assertRaises(ClientError):
            processing_lambda.call_bedrock_claude(self.sample_product_data)

    @patch.dict(os.environ, {
        'BEDROCK_REGION': 'us-east-1',
        'BEDROCK_MODEL': 'anthropic.claude-v2'
    })
    @patch('lambda_function.boto3.client')
    def test_bedrock_api_call_invalid_json(self, mock_boto_client):
        """Test Bedrock API call with invalid JSON response"""
        # Mock Bedrock client and invalid response
        mock_bedrock = Mock()
        mock_boto_client.return_value = mock_bedrock
        
        mock_response = {'body': Mock()}
        mock_response['body'].read.return_value = b'{"invalid": json}'
        mock_bedrock.invoke_model.return_value = mock_response
        
        # Test should raise exception
        with self.assertRaises(json.JSONDecodeError):
            processing_lambda.call_bedrock_claude(self.sample_product_data)

    @patch.dict(os.environ, {
        'BEDROCK_REGION': 'us-east-1',
        'BEDROCK_MODEL': 'anthropic.claude-v2'
    })
    @patch('lambda_function.boto3.client')
    def test_bedrock_api_call_no_content(self, mock_boto_client):
        """Test Bedrock API call with no content in response"""
        # Mock Bedrock client and empty response
        mock_bedrock = Mock()
        mock_boto_client.return_value = mock_bedrock
        
        mock_response = {'body': Mock()}
        mock_response['body'].read.return_value = json.dumps({
            'content': []
        }).encode('utf-8')
        mock_bedrock.invoke_model.return_value = mock_response
        
        # Test should raise exception
        with self.assertRaises(ValueError):
            processing_lambda.call_bedrock_claude(self.sample_product_data)

    def test_enrichment_prompt_structure(self):
        """Test enrichment prompt structure and content"""
        prompt = processing_lambda.create_enrichment_prompt(self.sample_product_data)
        
        # Verify prompt contains required elements
        required_elements = [
            'product data expert',
            'structured json response',
            'confidence score',
            'duplicate detection',
            'brand',
            'category',
            'color',
            'size',
            'price',
            'description'
        ]
        
        for element in required_elements:
            self.assertIn(element, prompt.lower())
        
        # Verify product data is included
        self.assertIn(json.dumps(self.sample_product_data), prompt)
        
        # Verify JSON response format is specified
        self.assertIn('"name_clean":', prompt)
        self.assertIn('"confidence_score":', prompt)
        self.assertIn('"duplicate_flag":', prompt)

    def test_enrichment_prompt_with_minimal_data(self):
        """Test enrichment prompt with minimal product data"""
        minimal_data = {'product_name': 'Test Product'}
        
        prompt = processing_lambda.create_enrichment_prompt(minimal_data)
        
        # Should still create valid prompt
        self.assertIn('product data expert', prompt.lower())
        self.assertIn(json.dumps(minimal_data), prompt)

    def test_enrichment_prompt_with_complex_data(self):
        """Test enrichment prompt with complex product data"""
        complex_data = {
            'product_name': 'Very Long Product Name With Many Details and Specifications',
            'price': '$1,299.99',
            'description': 'A very detailed product description with many features and benefits',
            'category': 'Electronics',
            'brand': 'Premium Brand',
            'color': 'Midnight Blue',
            'size': 'Large',
            'material': 'Carbon Fiber',
            'weight': '2.5kg',
            'dimensions': '30x20x10cm',
            'warranty': '2 years',
            'origin': 'Made in Germany'
        }
        
        prompt = processing_lambda.create_enrichment_prompt(complex_data)
        
        # Should handle complex data gracefully
        self.assertIn('product data expert', prompt.lower())
        self.assertIn(json.dumps(complex_data), prompt)

    def test_record_hash_generation(self):
        """Test record hash generation for duplicate detection"""
        # Generate hash for same data
        hash1 = processing_lambda.generate_record_hash(self.expected_enriched_data)
        hash2 = processing_lambda.generate_record_hash(self.expected_enriched_data)
        
        # Should be identical
        self.assertEqual(hash1, hash2)
        self.assertEqual(len(hash1), 32)  # MD5 hash length
        
        # Generate hash for different data
        different_data = self.expected_enriched_data.copy()
        different_data['brand'] = 'Adidas'
        hash3 = processing_lambda.generate_record_hash(different_data)
        
        # Should be different
        self.assertNotEqual(hash1, hash3)

    def test_record_hash_case_insensitive(self):
        """Test record hash generation is case insensitive"""
        data1 = self.expected_enriched_data.copy()
        data2 = self.expected_enriched_data.copy()
        data2['brand'] = 'NIKE'  # Different case
        
        hash1 = processing_lambda.generate_record_hash(data1)
        hash2 = processing_lambda.generate_record_hash(data2)
        
        # Should be the same (case insensitive)
        self.assertEqual(hash1, hash2)

    def test_record_hash_whitespace_handling(self):
        """Test record hash generation handles whitespace correctly"""
        data1 = self.expected_enriched_data.copy()
        data2 = self.expected_enriched_data.copy()
        data2['brand'] = ' Nike '  # Extra whitespace
        
        hash1 = processing_lambda.generate_record_hash(data1)
        hash2 = processing_lambda.generate_record_hash(data2)
        
        # Should be the same (whitespace trimmed)
        self.assertEqual(hash1, hash2)

    @patch.dict(os.environ, {
        'BEDROCK_REGION': 'us-east-1',
        'BEDROCK_MODEL': 'anthropic.claude-v2'
    })
    @patch('lambda_function.boto3.client')
    def test_bedrock_request_structure(self, mock_boto_client):
        """Test Bedrock request structure is correct"""
        # Mock Bedrock client
        mock_bedrock = Mock()
        mock_boto_client.return_value = mock_bedrock
        mock_response = {'body': Mock()}
        mock_response['body'].read.return_value = json.dumps({
            'content': [{'text': json.dumps(self.expected_enriched_data)}]
        }).encode('utf-8')
        mock_bedrock.invoke_model.return_value = mock_response
        
        # Call Bedrock
        processing_lambda.call_bedrock_claude(self.sample_product_data)
        
        # Verify request structure
        call_args = mock_bedrock.invoke_model.call_args
        request_body = json.loads(call_args[1]['body'])
        
        # Verify required fields
        self.assertIn('anthropic_version', request_body)
        self.assertIn('max_tokens', request_body)
        self.assertIn('messages', request_body)
        
        # Verify message structure
        message = request_body['messages'][0]
        self.assertEqual(message['role'], 'user')
        self.assertIn('content', message)
        
        # Verify prompt is in content
        self.assertIn('product data expert', message['content'])

    @patch.dict(os.environ, {
        'BEDROCK_REGION': 'us-west-2',
        'BEDROCK_MODEL': 'anthropic.claude-instant-v1'
    })
    @patch('lambda_function.boto3.client')
    def test_bedrock_different_region_model(self, mock_boto_client):
        """Test Bedrock call with different region and model"""
        # Mock Bedrock client
        mock_bedrock = Mock()
        mock_boto_client.return_value = mock_bedrock
        mock_response = {'body': Mock()}
        mock_response['body'].read.return_value = json.dumps({
            'content': [{'text': json.dumps(self.expected_enriched_data)}]
        }).encode('utf-8')
        mock_bedrock.invoke_model.return_value = mock_response
        
        # Call Bedrock
        result = processing_lambda.call_bedrock_claude(self.sample_product_data)
        
        # Verify correct client was called
        mock_boto_client.assert_called_with('bedrock-runtime', region_name='us-west-2')
        
        # Verify correct model was used
        call_args = mock_bedrock.invoke_model.call_args
        self.assertEqual(call_args[1]['modelId'], 'anthropic.claude-instant-v1')

    def test_enrichment_data_validation(self):
        """Test enrichment data structure validation"""
        # Test valid enriched data
        valid_data = {
            'name_clean': 'Test Product',
            'brand': 'Test Brand',
            'category': 'Test Category',
            'confidence_score': 0.85
        }
        
        # Should generate hash without errors
        hash_value = processing_lambda.generate_record_hash(valid_data)
        self.assertIsNotNone(hash_value)
        
        # Test data with missing fields
        incomplete_data = {
            'name_clean': 'Test Product'
            # Missing other required fields
        }
        
        # Should still generate hash
        hash_value = processing_lambda.generate_record_hash(incomplete_data)
        self.assertIsNotNone(hash_value)


if __name__ == '__main__':
    unittest.main()

"""
Unit Tests for Data Validation and Quality
"""

import unittest
from unittest.mock import Mock, patch
import json
import pandas as pd
import sys
import os

# Add the lambda directories to the path for testing
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lambda', 'ingestion'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lambda', 'processing'))

class TestDataValidation(unittest.TestCase):
    """Test cases for data validation and quality checks"""

    def setUp(self):
        """Set up test fixtures"""
        self.valid_csv_data = """product_name,price,description,category,brand,color
Nike Air Max 270,$129.99,Comfortable running shoes,Footwear,Nike,Black
Adidas Ultraboost 22,$159.99,High-performance shoes,Footwear,Adidas,White
Levi's 501 Jeans,$89.99,Classic straight fit jeans,Clothing,Levi's,Blue"""
        
        self.invalid_csv_data = """product_name,price,description,category,brand,color
Nike Air Max 270,$129.99,Comfortable running shoes,Footwear,Nike,Black
Adidas Ultraboost 22,invalid_price,High-performance shoes,Footwear,Adidas,White
Levi's 501 Jeans,$89.99,,Clothing,Levi's,Blue"""
        
        self.valid_enriched_data = {
            'name_clean': 'Nike Air Max 270 Running Shoes',
            'brand': 'Nike',
            'category': 'Footwear',
            'color': 'Black',
            'size': None,
            'price': '$129.99',
            'description_clean': 'Comfortable running shoes with air cushioning',
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
        
        self.invalid_enriched_data = {
            'name_clean': '',
            'brand': None,
            'category': '',
            'color': None,
            'size': None,
            'price': None,
            'description_clean': '',
            'duplicate_flag': False,
            'duplicate_reason': None,
            'confidence_score': 0.1,
            'extracted_attributes': {
                'material': None,
                'style': None,
                'gender': None,
                'season': None
            }
        }

    def test_csv_structure_validation(self):
        """Test CSV file structure validation"""
        import csv
        from io import StringIO
        
        # Test valid CSV structure
        csv_reader = csv.DictReader(StringIO(self.valid_csv_data))
        records = list(csv_reader)
        
        self.assertEqual(len(records), 3)
        self.assertIn('product_name', records[0])
        self.assertIn('price', records[0])
        self.assertIn('description', records[0])
        
        # Verify required field is present
        self.assertTrue(records[0]['product_name'])
        self.assertEqual(records[0]['brand'], 'Nike')

    def test_required_field_validation(self):
        """Test required field validation"""
        import csv
        from io import StringIO
        
        # Test CSV with missing required field
        invalid_csv = """price,description,category,brand,color
$129.99,Comfortable running shoes,Footwear,Nike,Black"""
        
        csv_reader = csv.DictReader(StringIO(invalid_csv))
        records = list(csv_reader)
        
        # Should still parse but missing product_name
        self.assertEqual(len(records), 1)
        self.assertNotIn('product_name', records[0])

    def test_price_format_validation(self):
        """Test price format validation"""
        import re
        
        valid_prices = ['$129.99', '$159.99', '$89.99', '129.99', '159.99', '89.99']
        invalid_prices = ['invalid_price', 'abc', '12.99.99', '', '   ']
        
        price_pattern = r'^\$\d+(\.\d{2})?$|^\d+(\.\d{2})?$'
        
        for price in valid_prices:
            self.assertTrue(re.match(price_pattern, price), f"Valid price {price} should match")
        
        for price in invalid_prices:
            self.assertFalse(re.match(price_pattern, price), f"Invalid price {price} should not match")

    def test_email_format_validation(self):
        """Test email format validation (if needed for notifications)"""
        import re
        
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        
        valid_emails = ['test@example.com', 'user.name@domain.co.uk', 'user+tag@example.org']
        invalid_emails = ['invalid-email', '@example.com', 'test@', 'test.example.com']
        
        for email in valid_emails:
            self.assertTrue(re.match(email_pattern, email), f"Valid email {email} should match")
        
        for email in invalid_emails:
            self.assertFalse(re.match(email_pattern, email), f"Invalid email {email} should not match")

    def test_enriched_data_quality_score(self):
        """Test enriched data quality scoring"""
        def calculate_quality_score(data):
            """Calculate quality score based on data completeness"""
            score = 0.0
            total_fields = 0
            
            # Required fields
            required_fields = ['name_clean', 'brand', 'category']
            for field in required_fields:
                total_fields += 1
                if data.get(field) and data[field].strip():
                    score += 1.0
            
            # Optional fields
            optional_fields = ['color', 'size', 'price', 'description_clean']
            for field in optional_fields:
                total_fields += 1
                if data.get(field) and data[field].strip():
                    score += 0.5
            
            # Extracted attributes
            if 'extracted_attributes' in data:
                attrs = data['extracted_attributes']
                for attr in ['material', 'style', 'gender', 'season']:
                    total_fields += 0.5
                    if attrs.get(attr) and attrs[attr].strip():
                        score += 0.25
            
            return min(1.0, score / total_fields)
        
        # Test high quality data
        high_quality_score = calculate_quality_score(self.valid_enriched_data)
        self.assertGreater(high_quality_score, 0.7)
        
        # Test low quality data
        low_quality_score = calculate_quality_score(self.invalid_enriched_data)
        self.assertLess(low_quality_score, 0.3)

    def test_duplicate_detection_logic(self):
        """Test duplicate detection logic"""
        def is_duplicate(record1, record2):
            """Simple duplicate detection based on key fields"""
            key_fields = ['name_clean', 'brand', 'category', 'color', 'size']
            
            for field in key_fields:
                val1 = str(record1.get(field, '')).strip().lower()
                val2 = str(record2.get(field, '')).strip().lower()
                
                if val1 and val2 and val1 != val2:
                    return False
            
            # If all non-empty key fields match, consider it a duplicate
            return True
        
        # Create two similar records
        record1 = {
            'name_clean': 'Nike Air Max 270 Running Shoes',
            'brand': 'Nike',
            'category': 'Footwear',
            'color': 'Black',
            'size': '10'
        }
        
        record2 = {
            'name_clean': 'Nike Air Max 270 Running Shoes',
            'brand': 'Nike',
            'category': 'Footwear',
            'color': 'Black',
            'size': '10'
        }
        
        record3 = {
            'name_clean': 'Nike Air Max 270 Running Shoes',
            'brand': 'Adidas',  # Different brand
            'category': 'Footwear',
            'color': 'Black',
            'size': '10'
        }
        
        # Test duplicate detection
        self.assertTrue(is_duplicate(record1, record2))
        self.assertFalse(is_duplicate(record1, record3))

    def test_confidence_score_validation(self):
        """Test confidence score validation"""
        def validate_confidence_score(data):
            """Validate confidence score is reasonable"""
            score = data.get('confidence_score', 0)
            
            # Score should be between 0 and 1
            if not (0.0 <= score <= 1.0):
                return False
            
            # Low quality data should have low confidence
            if score > 0.7 and not data.get('name_clean'):
                return False
            
            # High confidence should have required fields
            if score > 0.9 and not all([
                data.get('name_clean'),
                data.get('brand'),
                data.get('category')
            ]):
                return False
            
            return True
        
        # Test valid confidence score
        self.assertTrue(validate_confidence_score(self.valid_enriched_data))
        
        # Test invalid confidence score
        invalid_data = self.valid_enriched_data.copy()
        invalid_data['confidence_score'] = 1.5  # Invalid score
        self.assertFalse(validate_confidence_score(invalid_data))

    def test_data_sanitization(self):
        """Test data sanitization"""
        import re
        
        def sanitize_text(text):
            """Sanitize text by removing special characters and normalizing"""
            if not text:
                return text
            
            # Remove extra whitespace
            text = re.sub(r'\s+', ' ', text.strip())
            
            # Remove special characters except basic punctuation
            text = re.sub(r'[^\w\s\-\.\,\/]', '', text)
            
            return text
        
        # Test text sanitization
        test_cases = [
            ('  Nike Air Max 270  ', 'Nike Air Max 270'),
            ('Nike@Air#Max$270', 'Nike Air Max 270'),
            ('Nike\nAir\tMax\r270', 'Nike Air Max 270'),
            ('', ''),
            (None, None)
        ]
        
        for input_text, expected in test_cases:
            result = sanitize_text(input_text)
            self.assertEqual(result, expected)

    def test_file_size_validation(self):
        """Test file size validation"""
        def validate_file_size(size_bytes, max_size_mb=10):
            """Validate file size is within limits"""
            max_size_bytes = max_size_mb * 1024 * 1024
            return size_bytes <= max_size_bytes
        
        # Test file sizes
        self.assertTrue(validate_file_size(1024 * 1024))  # 1MB
        self.assertTrue(validate_file_size(10 * 1024 * 1024))  # 10MB
        self.assertFalse(validate_file_size(11 * 1024 * 1024))  # 11MB
        self.assertFalse(validate_file_size(50 * 1024 * 1024))  # 50MB

    def test_record_count_validation(self):
        """Test record count validation"""
        def validate_record_count(count, max_records=10000):
            """Validate record count is within limits"""
            return count <= max_records
        
        # Test record counts
        self.assertTrue(validate_record_count(100))
        self.assertTrue(validate_record_count(1000))
        self.assertTrue(validate_record_count(10000))
        self.assertFalse(validate_record_count(10001))
        self.assertFalse(validate_record_count(50000))

    def test_json_schema_validation(self):
        """Test JSON schema validation for enriched data"""
        def validate_enriched_schema(data):
            """Validate enriched data follows expected schema"""
            required_fields = ['name_clean', 'brand', 'category', 'confidence_score']
            
            # Check required fields
            for field in required_fields:
                if field not in data:
                    return False
            
            # Check data types
            if not isinstance(data['confidence_score'], (int, float)):
                return False
            
            if not isinstance(data['duplicate_flag'], bool):
                return False
            
            # Check value ranges
            if not (0.0 <= data['confidence_score'] <= 1.0):
                return False
            
            return True
        
        # Test valid schema
        self.assertTrue(validate_enriched_schema(self.valid_enriched_data))
        
        # Test invalid schema
        invalid_schema = self.valid_enriched_data.copy()
        invalid_schema.pop('name_clean')
        self.assertFalse(validate_enriched_schema(invalid_schema))
        
        # Test invalid data types
        invalid_types = self.valid_enriched_data.copy()
        invalid_types['confidence_score'] = 'invalid'
        self.assertFalse(validate_enriched_schema(invalid_types))

    def test_batch_processing_validation(self):
        """Test batch processing validation"""
        def validate_batch_size(batch_size, min_size=1, max_size=100):
            """Validate batch size is within acceptable range"""
            return min_size <= batch_size <= max_size
        
        # Test batch sizes
        self.assertTrue(validate_batch_size(10))
        self.assertTrue(validate_batch_size(50))
        self.assertTrue(validate_batch_size(100))
        self.assertFalse(validate_batch_size(0))
        self.assertFalse(validate_batch_size(101))
        self.assertFalse(validate_batch_size(500))

    def test_error_handling_validation(self):
        """Test error handling validation"""
        def create_error_response(error_message, error_type='ValidationError'):
            """Create standardized error response"""
            return {
                'error': True,
                'error_type': error_type,
                'message': error_message,
                'timestamp': '2024-01-15T10:30:00Z'
            }
        
        # Test error response creation
        error_response = create_error_response('Test error message')
        
        self.assertTrue(error_response['error'])
        self.assertEqual(error_response['error_type'], 'ValidationError')
        self.assertEqual(error_response['message'], 'Test error message')
        self.assertIn('timestamp', error_response)

    def test_data_transformation_validation(self):
        """Test data transformation validation"""
        def transform_product_name(name):
            """Transform product name to clean format"""
            if not name:
                return name
            
            # Remove common prefixes/suffixes
            name = re.sub(r'\b(men\'s|women\'s|unisex)\b', '', name, flags=re.IGNORECASE)
            
            # Normalize case
            name = ' '.join(word.capitalize() for word in name.split())
            
            return name.strip()
        
        import re
        
        # Test transformations
        test_cases = [
            ('nike air max 270', 'Nike Air Max 270'),
            ("Men's Nike Air Max 270", 'Nike Air Max 270'),
            ('WOMENS ADIDAS ULTRABOOST', 'Adidas Ultraboost'),
            ('', ''),
            (None, None)
        ]
        
        for input_name, expected in test_cases:
            result = transform_product_name(input_name)
            self.assertEqual(result, expected)


if __name__ == '__main__':
    unittest.main()

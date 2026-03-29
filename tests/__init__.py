"""
Test Suite for AI-Powered Product Catalog Ingestion Pipeline
"""

import os
import sys
import unittest
from unittest.mock import Mock, patch, MagicMock

# Add the lambda directories to the path for testing
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lambda', 'ingestion'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lambda', 'processing'))

# Test configuration
TEST_CONFIG = {
    'DB_HOST': 'localhost',
    'DB_NAME': 'test_productcatalog',
    'DB_USER': 'test_user',
    'DB_PASSWORD': 'test_password',
    'PROCESSED_BUCKET': 'test-processed-bucket',
    'BEDROCK_REGION': 'us-east-1',
    'BEDROCK_MODEL': 'anthropic.claude-v2'
}

# Sample test data
SAMPLE_CSV_DATA = """product_name,price,description,category,brand,color
Nike Air Max 270,$129.99,Comfortable running shoes with air cushioning,Footwear,Nike,Black
Adidas Ultraboost 22,$159.99,High-performance running shoes,Footwear,Adidas,White
Levi's 501 Jeans,$89.99,Classic straight fit jeans,Clothing,Levi's,Blue"""

SAMPLE_PRODUCT_RECORD = {
    'product_name': 'Nike Air Max 270 Running Shoes',
    'price': '$129.99',
    'description': 'Comfortable running shoes with air cushioning',
    'category': 'Footwear',
    'brand': 'Nike',
    'color': 'Black'
}

SAMPLE_ENRICHED_DATA = {
    'name_clean': 'Nike Air Max 270 Running Shoes',
    'brand': 'Nike',
    'category': 'Footwear',
    'color': 'Black',
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
    },
    'processing_timestamp': '2024-01-15T10:30:00Z',
    'bedrock_model': 'anthropic.claude-v2',
    'raw_record_id': 123,
    'file_name': 'test_products.csv',
    'row_number': 1
}

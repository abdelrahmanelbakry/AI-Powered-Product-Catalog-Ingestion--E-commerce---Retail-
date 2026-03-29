"""
AWS Lambda function for ChatBot integration with Bedrock
Handles natural language queries and data quality rule execution
"""

import json
import os
import boto3
import psycopg2
from psycopg2.extras import RealDictCursor
import re
from datetime import datetime

# Initialize AWS clients
bedrock_runtime = boto3.client('bedrock-runtime')
s3_client = boto3.client('s3')

# Environment variables
DB_HOST = os.environ['DB_HOST']
DB_NAME = os.environ['DB_NAME']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']
PROCESSED_BUCKET = os.environ.get('PROCESSED_BUCKET', 'product-catalog-dev-processed')
BEDROCK_REGION = os.environ.get('BEDROCK_REGION', 'us-east-1')
BEDROCK_MODEL = os.environ.get('BEDROCK_MODEL', 'anthropic.claude-v2')

def lambda_handler(event, context):
    """
    Main Lambda handler for ChatBot requests
    """
    try:
        # Parse request
        body = json.loads(event.get('body', '{}'))
        user_message = body.get('message', '')
        session_id = body.get('session_id', 'default')
        
        if not user_message:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Message is required'
                })
            }
        
        # Process the message
        response = process_chat_message(user_message, session_id)
        
        return {
            'statusCode': 200,
            'body': json.dumps(response)
        }
        
    except Exception as e:
        print(f"Error processing chat message: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal server error',
                'details': str(e)
            })
        }

def process_chat_message(message, session_id):
    """
    Process user message and generate response
    """
    # Check if it's a data quality rule
    rule = parse_data_quality_rule(message)
    if rule:
        return execute_data_quality_rule(rule)
    
    # Handle general data queries
    if is_data_query(message):
        return handle_data_query(message)
    
    # Handle general conversation
    return handle_general_conversation(message)

def parse_data_quality_rule(message):
    """
    Parse natural language data quality rule
    """
    rule_patterns = {
        'null_check': r'\b(no|null|empty|missing)\s+(name|brand|category|price|color)\b',
        'price_range': r'\b(price|cost)\s+(should|must|between)\s+\$(\d+)\s+and\s+\$(\d+)\b',
        'category_validation': r'\b(category|type)\s+(should|must|be)\s+(one of|in)\s+([a-z,\s]+)\b',
        'brand_validation': r'\b(brand|manufacturer)\s+(should|must)\s+(not be empty|not be null|be valid)\b',
        'name_length': r'\b(name|product name)\s+(should|must)\s+(be at least|be longer than)\s+(\d+)\s+characters\b',
        'duplicate_detection': r'\b(no duplicates|no duplicate|unique)\s+(names|products|records)\b',
        'completeness_check': r'\b(all records|every record)\s+(should|must)\s+have\s+(complete|all|required)\s+(fields|data)\b'
    }
    
    for rule_type, pattern in rule_patterns.items():
        match = re.search(pattern, message, re.IGNORECASE)
        if match:
            return {
                'type': rule_type,
                'match': match.groups(),
                'original_input': message
            }
    
    return None

def execute_data_quality_rule(rule):
    """
    Execute data quality rule against the database
    """
    try:
        # Connect to database
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            results = execute_rule_by_type(cursor, rule)
            
            # Generate report
            report = generate_quality_report(rule, results)
            
            # Save report to S3
            save_report_to_s3(report)
            
            conn.close()
            
            return {
                'type': 'quality_report',
                'content': format_quality_response(rule, report),
                'report_id': report['id'],
                'metrics': report['metrics']
            }
            
    except Exception as e:
        print(f"Error executing data quality rule: {str(e)}")
        return {
            'type': 'error',
            'content': f"Sorry, I couldn't execute the data quality rule: {str(e)}"
        }

def execute_rule_by_type(cursor, rule):
    """
    Execute specific rule type against database
    """
    rule_type = rule['type']
    
    if rule_type == 'null_check':
        field = rule['match'][0]
        query = f"""
        SELECT id, {field} as field_value, '{field}' as field_name
        FROM raw_products 
        WHERE {field} IS NULL OR {field} = '' OR {field} = 'NULL'
        """
        cursor.execute(query)
        return cursor.fetchall()
    
    elif rule_type == 'price_range':
        min_price = float(rule['match'][1])
        max_price = float(rule['match'][2])
        query = """
        SELECT id, price as field_value, 'price' as field_name
        FROM raw_products 
        WHERE price IS NOT NULL 
        AND price != ''
        AND price != 'NULL'
        AND CAST(REGEXP_REPLACE(price, '[^0-9.]', '', 'g') AS DECIMAL) < %s
        OR CAST(REGEXP_REPLACE(price, '[^0-9.]', '', 'g') AS DECIMAL) > %s
        """
        cursor.execute(query, (min_price, max_price))
        return cursor.fetchall()
    
    elif rule_type == 'category_validation':
        valid_categories = [cat.strip() for cat in rule['match'][1].split(',')]
        query = """
        SELECT id, category as field_value, 'category' as field_name
        FROM raw_products 
        WHERE category IS NOT NULL 
        AND category != ''
        AND category NOT IN %s
        """
        cursor.execute(query, (tuple(valid_categories),))
        return cursor.fetchall()
    
    elif rule_type == 'brand_validation':
        query = """
        SELECT id, brand as field_value, 'brand' as field_name
        FROM raw_products 
        WHERE brand IS NULL OR brand = '' OR brand = 'NULL'
        """
        cursor.execute(query)
        return cursor.fetchall()
    
    elif rule_type == 'name_length':
        min_length = int(rule['match'][0])
        query = """
        SELECT id, product_name as field_value, 'product_name' as field_name
        FROM raw_products 
        WHERE product_name IS NOT NULL 
        AND LENGTH(product_name) < %s
        """
        cursor.execute(query, (min_length,))
        return cursor.fetchall()
    
    elif rule_type == 'duplicate_detection':
        query = """
        SELECT product_name, COUNT(*) as count
        FROM raw_products 
        WHERE product_name IS NOT NULL AND product_name != ''
        GROUP BY product_name 
        HAVING COUNT(*) > 1
        """
        cursor.execute(query)
        return cursor.fetchall()
    
    elif rule_type == 'completeness_check':
        query = """
        SELECT id, 
               CASE 
                   WHEN product_name IS NULL OR product_name = '' THEN 'product_name' 
                   WHEN brand IS NULL OR brand = '' THEN 'brand'
                   WHEN category IS NULL OR category = '' THEN 'category'
                   WHEN price IS NULL OR price = '' THEN 'price'
               END as missing_field
        FROM raw_products 
        WHERE (product_name IS NULL OR product_name = '' OR product_name = 'NULL')
           OR (brand IS NULL OR brand = '' OR brand = 'NULL')
           OR (category IS NULL OR category = '' OR category = 'NULL')
           OR (price IS NULL OR price = '' OR price = 'NULL')
        """
        cursor.execute(query)
        return cursor.fetchall()
    
    else:
        return []

def generate_quality_report(rule, results):
    """
    Generate comprehensive quality report
    """
    # Get total record count
    total_records = get_total_record_count()
    
    failed_records = len(results)
    passed_records = total_records - failed_records
    pass_rate = (passed_records / total_records * 100) if total_records > 0 else 0
    
    report = {
        'id': f"quality_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
        'rule': rule['original_input'],
        'rule_type': rule['type'],
        'timestamp': datetime.now().isoformat(),
        'metrics': {
            'total_records': total_records,
            'passed_records': passed_records,
            'failed_records': failed_records,
            'pass_rate': round(pass_rate, 1)
        },
        'issues': [
            {
                'id': result.get('id', i),
                'field': result.get('field_name', 'unknown'),
                'value': result.get('field_value', 'N/A'),
                'issue': format_issue_description(rule, result)
            }
            for i, result in enumerate(results)
        ],
        'recommendations': generate_recommendations(rule, failed_records, pass_rate)
    }
    
    return report

def get_total_record_count():
    """
    Get total record count from database
    """
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        
        with conn.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM raw_products")
            count = cursor.fetchone()[0]
            conn.close()
            return count
            
    except Exception as e:
        print(f"Error getting record count: {str(e)}")
        return 0

def format_issue_description(rule, result):
    """
    Format human-readable issue description
    """
    rule_type = rule['type']
    field = result.get('field_name', 'unknown')
    value = result.get('field_value', 'N/A')
    
    descriptions = {
        'null_check': f"{field} is null or empty",
        'price_range': f"price {value} is outside valid range",
        'category_validation': f"category '{value}' is not in allowed list",
        'brand_validation': f"brand is null or empty",
        'name_length': f"product name length is too short",
        'duplicate_detection': f"duplicate product found: {value}",
        'completeness_check': f"missing required field: {value}"
    }
    
    return descriptions.get(rule_type, f"Quality issue detected in {field}")

def generate_recommendations(rule, failed_count, pass_rate):
    """
    Generate actionable recommendations
    """
    recommendations = []
    
    if failed_count == 0:
        recommendations.append("🎉 Excellent data quality! All records passed the validation.")
    else:
        recommendations.append(f"🔧 Address {failed_count} data quality issues identified.")
        
        if pass_rate < 90:
            recommendations.append("⚠️ Low pass rate detected. Consider implementing data validation at the source.")
        
        if rule['type'] in ['null_check', 'completeness_check']:
            recommendations.append("📝 Implement required field validation in data entry forms.")
        
        if rule['type'] == 'price_range':
            recommendations.append("💰 Add price format and range validation.")
        
        if rule['type'] == 'duplicate_detection':
            recommendations.append("🔍 Implement duplicate detection and prevention logic.")
    
    return recommendations

def format_quality_response(rule, report):
    """
    Format quality report response for chat
    """
    metrics = report['metrics']
    issues = report['issues']
    
    response = f"""I've analyzed your data using the rule: "{rule['original_input']}"

{report['recommendations'][0]}

📊 **Details:**
• Total Records: {metrics['total_records']}
• Passed: {metrics['passed_records']}
• Failed: {metrics['failed_records']}
• Pass Rate: {metrics['pass_rate']}%

🔍 **Issues Found:**
"""
    
    # Add first 5 issues to avoid too long responses
    for issue in issues[:5]:
        response += f"• Record {issue['id']}: {issue['issue']}\n"
    
    if len(issues) > 5:
        response += f"... and {len(issues) - 5} more issues\n"
    
    response += f"\n💡 **Recommendations:**\n"
    for rec in report['recommendations']:
        response += f"• {rec}\n"
    
    response += "\nI've saved a detailed report. Would you like me to run another quality check?"
    
    return response

def save_report_to_s3(report):
    """
    Save quality report to S3
    """
    try:
        key = f"quality-reports/{report['id']}.json"
        
        s3_client.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=key,
            Body=json.dumps(report, indent=2, default=str),
            ContentType='application/json'
        )
        
        print(f"Quality report saved to S3: {key}")
        
    except Exception as e:
        print(f"Error saving report to S3: {str(e)}")

def is_data_query(message):
    """
    Check if message is a data query
    """
    query_patterns = [
        r'\b(how many|count|show me|list|what|which)\b',
        r'\b(products|records|items)\b',
        r'\b(category|brand|price|name)\b'
    ]
    
    return any(re.search(pattern, message, re.IGNORECASE) for pattern in query_patterns)

def handle_data_query(message):
    """
    Handle general data queries
    """
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            # Parse the query and execute appropriate SQL
            result = execute_data_query(cursor, message)
            conn.close()
            
            return {
                'type': 'data_query',
                'content': format_query_response(result)
            }
            
    except Exception as e:
        print(f"Error handling data query: {str(e)}")
        return {
            'type': 'error',
            'content': f"Sorry, I couldn't process your data query: {str(e)}"
        }

def execute_data_query(cursor, message):
    """
    Execute data query based on message content
    """
    message_lower = message.lower()
    
    if 'how many' in message_lower or 'count' in message_lower:
        if 'category' in message_lower:
            cursor.execute("""
            SELECT category, COUNT(*) as count 
            FROM raw_products 
            WHERE category IS NOT NULL AND category != ''
            GROUP BY category
            ORDER BY count DESC
            """)
            return cursor.fetchall()
        else:
            cursor.execute("SELECT COUNT(*) as total FROM raw_products")
            return cursor.fetchall()
    
    elif 'show me' in message_lower or 'list' in message_lower:
        if 'footwear' in message_lower:
            cursor.execute("""
            SELECT id, product_name, brand, price 
            FROM raw_products 
            WHERE category ILIKE '%footwear%'
            LIMIT 10
            """)
            return cursor.fetchall()
        elif 'clothing' in message_lower:
            cursor.execute("""
            SELECT id, product_name, brand, price 
            FROM raw_products 
            WHERE category ILIKE '%clothing%'
            LIMIT 10
            """)
            return cursor.fetchall()
        elif 'electronics' in message_lower:
            cursor.execute("""
            SELECT id, product_name, brand, price 
            FROM raw_products 
            WHERE category ILIKE '%electronics%'
            LIMIT 10
            """)
            return cursor.fetchall()
        else:
            cursor.execute("""
            SELECT id, product_name, brand, category, price 
            FROM raw_products 
            LIMIT 10
            """)
            return cursor.fetchall()
    
    else:
        cursor.execute("""
        SELECT category, COUNT(*) as count, AVG(
            CASE 
                WHEN price IS NOT NULL AND price != '' AND price != 'NULL'
                THEN CAST(REGEXP_REPLACE(price, '[^0-9.]', '', 'g') AS DECIMAL)
                ELSE NULL
            END
        ) as avg_price
        FROM raw_products 
        WHERE category IS NOT NULL AND category != ''
        GROUP BY category
        ORDER BY count DESC
        """)
        return cursor.fetchall()

def format_query_response(result):
    """
    Format query response for chat
    """
    if not result:
        return "📊 No data found matching your query."
    
    if isinstance(result, list) and len(result) > 0:
        first_item = result[0]
        
        if 'total' in first_item:
            total = first_item['total']
            return f"📊 **Data Query Results:**\n\nThere are {total} total products in the catalog.\n\nWould you like to see more details about specific categories?"
        
        elif 'category' in first_item and 'count' in first_item:
            response = "📊 **Products by Category:**\n\n"
            for item in result:
                response += f"• {item['category']}: {item['count']} products\n"
            response += "\nWould you like to see products from any specific category?"
            return response
        
        elif 'product_name' in first_item:
            response = "📋 **Product List:**\n\n"
            for item in result[:10]:
                response += f"• {item['product_name']} - {item['brand']} - ${item.get('price', 'N/A')}\n"
            if len(result) > 10:
                response += f"... and {len(result) - 10} more products\n"
            response += "\nWould you like more details about any specific product?"
            return response
    
    return "📊 Here's your data query result. Let me know if you'd like to explore further!"

def handle_general_conversation(message):
    """
    Handle general conversation and provide help
    """
    help_text = """I can help you analyze your product catalog data! Try asking me to:

📊 **Data Queries:**
• "How many products do we have?"
• "Show me all footwear products"
• "List products by category"

🔍 **Data Quality Rules:**
• "Check for missing product names"
• "Price should be between $50 and $500"
• "Category should be one of Footwear, Clothing, Electronics"
• "Brand must not be empty"
• "No duplicate products"

📈 **Analysis:**
• "What's the average price by category?"
• "Show me data quality issues"
• "Generate a quality report"

What would you like to explore?"""
    
    return {
        'type': 'general',
        'content': help_text
    }

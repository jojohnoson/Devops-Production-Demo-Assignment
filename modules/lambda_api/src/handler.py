import json
import base64
import boto3
import os

s3_client = boto3.client('s3')
BUCKET_NAME = os.environ['BUCKET_NAME']

def lambda_handler(event, context):
    try:
        body = event.get('body', '')
        is_base64 = event.get('isBase64Encoded', False)
        file_content = base64.b64decode(body) if is_base64 else body.encode('utf-8')
        
        if len(file_content) == 0:
            return {'statusCode': 400, 'body': json.dumps({'error': 'Empty file upload'})}
            
        file_name = event.get('queryStringParameters', {}).get('filename', 'uploaded-file.txt')
        
        s3_client.put_object(Bucket=BUCKET_NAME, Key=file_name, Body=file_content)
        
        return {'statusCode': 200, 'body': json.dumps({'message': 'Successfully uploaded file to S3', 'filename': file_name})}
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
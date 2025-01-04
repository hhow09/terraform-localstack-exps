import boto3
import uuid
from base64 import b64decode
from datetime import datetime as dt

ddb = boto3.Session(region_name='us-east-1').client(
    'dynamodb',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    endpoint_url='http://localstack:4566'
)

def decode_base64(string_to_decode):
    response = b64decode(string_to_decode).decode('utf-8')
    return response

def write_to_dynamodb(event_id, order_id, value):
    response = ddb.put_item(
        TableName='orders',
        Item={
            'EventID': {'S': event_id},
            'Data': {'S': value},
            'OrderID': {'S': order_id},
            'Timestamp': {'S': dt.now().strftime("%Y-%m-%dT%H:%M:%S")}
        }
    )
    return response

# ref: https://docs.aws.amazon.com/lambda/latest/dg/with-kinesis-example.html
def lambda_handler(event, request):
    for record in event['Records']:
        event_id = record['eventID']
        order_id = str(uuid.uuid4())
        value = decode_base64(record['kinesis']['data'])
        item = write_to_dynamodb(event_id, order_id, value)
        print('EventID: {}, HashKey: {}, Data: {}'.format(event_id, order_id, value))
        print('DynamoDB RequestID: {}'.format(item['ResponseMetadata']['RequestId']))
    return event

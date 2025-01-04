# https://registry.terraform.io/providers/hashicorp/archive/latest/docs/resources/file
data "archive_file" "order_processor_package" {
  type             = "zip"
  source_file      = "${path.module}/lambda/order-processor/src/lambda_function.py"
  output_file_mode = "0666"
  output_path      = "/tmp/deployment_package.zip"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table#basic-example
resource "aws_dynamodb_table" "orders" {
  name           = "orders"
  billing_mode   = "PROVISIONED"
  read_capacity  = "1"
  write_capacity = "5"
  hash_key       = "OrderID"

  attribute {
    name = "OrderID"
    type = "S"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_stream#example-usage
resource "aws_kinesis_stream" "orders_stream" {
  name             = "orders_stream"
  shard_count      = 1
  retention_period = 30

  # CloudWatch metrics
  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]
}

# lambda
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function#basic-example
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_lambda_function" "order_processor" {
  function_name    = "order_processor"
  filename         = "${path.module}/lambda/order-processor/deployment_package.zip"
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.iam_for_lambda.arn
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 128
  source_code_hash = data.archive_file.order_processor_package.output_base64sha256
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping
# This allows Lambda functions to get events from Kinesis, DynamoDB, SQS, Amazon MQ and Managed Streaming for Apache Kafka (MSK).
resource "aws_lambda_event_source_mapping" "order_processor_trigger" {
  event_source_arn              = aws_kinesis_stream.orders_stream.arn
  function_name                 = "order_processor"
  batch_size                    = 1
  starting_position             = "LATEST"
  enabled                       = true
  maximum_record_age_in_seconds = 604800
}

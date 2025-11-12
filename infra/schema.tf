# S3 bucket for schema file
resource "aws_s3_bucket" "schema" {
  bucket = "dms-demo-schema-${random_id.suffix.hex}"

  force_destroy = true

  tags = {
    Name = "dms-demo-schema"
  }
}

resource "aws_s3_bucket_versioning" "schema" {
  bucket = aws_s3_bucket.schema.id
  versioning_configuration {
    status = "Disabled"
  }
}

# Upload schema file to S3 if it exists
resource "aws_s3_object" "schema_sql" {
  count  = fileexists("${path.module}/../sct/converted_schema.sql") ? 1 : 0
  bucket = aws_s3_bucket.schema.id
  key    = "converted_schema.sql"
  source = "${path.module}/../sct/converted_schema.sql"

  etag = filemd5("${path.module}/../sct/converted_schema.sql")
}

# =============================================================================
# LAMBDA LAYERS
# =============================================================================

# Download layer ZIP from URL
data "http" "layer_zip" {
  url = local.layer_zip_url
  request_headers = {
    Accept = "application/octet-stream"
  }
}

# Save downloaded ZIP to local file
resource "local_file" "downloaded_zip" {
  filename       = "${path.module}/psycopg2-layer.zip"
  content_base64 = data.http.layer_zip.response_body_base64
}

# Security group for Lambda
resource "aws_security_group" "lambda" {
  name        = "lambda-schema-applier-sg"
  description = "Security group for Lambda schema applier"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lambda-schema-applier-sg"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_schema" {
  name = "lambda-schema-applier-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "lambda-schema-applier-role"
  }
}

# IAM policy for Lambda
resource "aws_iam_role_policy" "lambda_schema" {
  name = "lambda-schema-applier-policy"
  role = aws_iam_role.lambda_schema.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.schema.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "events:DisableRule",
          "events:DescribeRule"
        ]
        Resource = "arn:aws:events:${data.aws_region.current.region}:*:rule/dms-demo-schema-applier-*"
      }
    ]
  })
}

resource "aws_lambda_layer_version" "psycopg2" {
  layer_name               = "psycopg2-layer-${random_id.suffix.hex}"
  compatible_runtimes      = ["python3.12"]
  compatible_architectures = ["x86_64"]
  description              = "Psycopg2 layer for PostgreSQL connection"
  filename                 = local_file.downloaded_zip.filename
  source_code_hash         = base64sha256(data.http.layer_zip.response_body)
}

# Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_schema_applier.zip"
  source {
    content  = <<-EOF
import json
import boto3
import os
import sys

# Add layer path - Lambda layers are mounted at /opt
sys.path.insert(0, '/opt/python')

try:
    import psycopg2
except ImportError as e:
    raise Exception(f"psycopg2 not found in Lambda layer. Error: {str(e)}. Ensure the layer is correctly configured.")

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    events = boto3.client('events')

    bucket = os.environ['SCHEMA_BUCKET']
    key = os.environ['SCHEMA_KEY']
    endpoint = os.environ['AURORA_ENDPOINT']
    db_name = os.environ['AURORA_DB_NAME']
    db_user = os.environ['AURORA_USER']
    db_password = os.environ['AURORA_PASSWORD']
    rule_name = os.environ['EVENTBRIDGE_RULE_NAME']

    try:
        # Download schema file from S3
        response = s3.get_object(Bucket=bucket, Key=key)
        schema_sql = response['Body'].read().decode('utf-8')

        # Skip if file is empty or only comments
        lines = [l.strip() for l in schema_sql.split('\n') if l.strip() and not l.strip().startswith('--')]
        if not lines:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Schema file is empty, skipping'})
            }

        # Connect to Aurora
        conn = psycopg2.connect(
            host=endpoint,
            database=db_name,
            user=db_user,
            password=db_password,
            port=5432,
            connect_timeout=10
        )

        cursor = conn.cursor()

        # Execute schema SQL (split by semicolon for multiple statements)
        statements = [s.strip() for s in schema_sql.split(';') if s.strip() and not s.strip().startswith('--')]
        for statement in statements:
            if statement:
                cursor.execute(statement)
        conn.commit()

        cursor.close()
        conn.close()

        # Disable EventBridge rule on success
        try:
            events.disable_rule(Name=rule_name)
            rule_disabled = True
        except Exception as e:
            rule_disabled = False
            print(f"Warning: Could not disable rule: {str(e)}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Schema applied successfully',
                'rule_disabled': rule_disabled
            })
        }

    except psycopg2.OperationalError as e:
        # Aurora might not be ready yet, retry on next invocation
        error_msg = str(e)
        if 'could not connect' in error_msg.lower() or 'timeout' in error_msg.lower():
            return {
                'statusCode': 202,
                'body': json.dumps({
                    'message': f'Aurora not ready yet: {error_msg}',
                    'will_retry': True
                })
            }
        # Other operational errors - might be schema issues
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Database error: {error_msg}',
                'will_retry': False
            })
        }
    except Exception as e:
        # Other errors - log but don't disable rule
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Error applying schema: {str(e)}',
                'will_retry': True
            })
        }
EOF
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "schema_applier" {
  count         = fileexists("${path.module}/../sct/converted_schema.sql") ? 1 : 0
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "dms-demo-schema-applier-${random_id.suffix.hex}"
  role          = aws_iam_role.lambda_schema.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 256

  layers = [aws_lambda_layer_version.psycopg2.arn]

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SCHEMA_BUCKET         = aws_s3_bucket.schema.id
      SCHEMA_KEY            = "converted_schema.sql"
      AURORA_ENDPOINT       = module.aurora.writer_endpoint
      AURORA_DB_NAME        = local.aurora_db_name
      AURORA_USER           = local.aurora_master_user
      AURORA_PASSWORD       = random_password.aurora_password.result
      EVENTBRIDGE_RULE_NAME = aws_cloudwatch_event_rule.schema_applier[0].name
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_schema,
    aws_cloudwatch_log_group.lambda_schema[0]
  ]

  tags = {
    Name = "dms-demo-schema-applier"
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_schema" {
  count = fileexists("${path.module}/../sct/converted_schema.sql") ? 1 : 0
  name  = "/aws/lambda/dms-demo-schema-applier-${random_id.suffix.hex}"

  lifecycle {
    prevent_destroy = false
  }

  retention_in_days = 1
}

# EventBridge rule to trigger Lambda every minute (only if schema file exists)
resource "aws_cloudwatch_event_rule" "schema_applier" {
  count               = fileexists("${path.module}/../sct/converted_schema.sql") ? 1 : 0
  name                = "dms-demo-schema-applier-${random_id.suffix.hex}"
  description         = "Trigger schema applier Lambda every minute"
  schedule_expression = "rate(1 minute)"
  state               = "ENABLED"

  tags = {
    Name = "dms-demo-schema-applier-rule"
  }
}

# EventBridge target
resource "aws_cloudwatch_event_target" "schema_applier" {
  count     = fileexists("${path.module}/../sct/converted_schema.sql") ? 1 : 0
  rule      = aws_cloudwatch_event_rule.schema_applier[0].name
  target_id = "SchemaApplierTarget"
  arn       = aws_lambda_function.schema_applier[0].arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "schema_applier" {
  count         = fileexists("${path.module}/../sct/converted_schema.sql") ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.schema_applier[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schema_applier[0].arn
}

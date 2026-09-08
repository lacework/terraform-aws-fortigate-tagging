provider "aws" {
  region = var.aws_region
}

# Declared explicitly so retention is enforced and `terraform destroy` removes it.
# Must exist before the first invocation, otherwise the runtime creates it implicitly.
resource "aws_cloudwatch_log_group" "forticnapp_lambda" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "forticnapp_lambda" {
  depends_on       = [aws_cloudwatch_log_group.forticnapp_lambda]
  filename         = var.lambda_zip_file
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.14"
  source_code_hash = filebase64sha256(var.lambda_zip_file)
  environment {
    variables = {
      TAG_KEY = var.tag_key
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = var.lambda_execution_role_name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ec2_tagging_policy" {
  name = var.tagging_policy_name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_fcnapp_ec2_tags" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.ec2_tagging_policy.arn
}

# aws_iam_role_policy_attachment, not aws_iam_policy_attachment: the latter is
# exclusive and detaches this managed policy from every other role in the account.
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_event_bus" "forticnapp_event_bus" {
  name = var.event_bus_name
}

# A custom bus accepts events only from its own account until a resource policy
# says otherwise. FortiCNAPP publishes cross-account, so without this policy the
# alert channel test succeeds but no event is ever delivered. Same policy as
# documented under "Amazon EventBridge Alert Channel > Creating an event bus".
resource "aws_cloudwatch_event_bus_policy" "allow_forticnapp" {
  event_bus_name = aws_cloudwatch_event_bus.forticnapp_event_bus.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "allow_account_to_put_events"
      Effect    = "Allow"
      Principal = { AWS = var.publisher_account_ids }
      Action    = "events:PutEvents"
      Resource  = aws_cloudwatch_event_bus.forticnapp_event_bus.arn
    }]
  })
}

resource "aws_cloudwatch_event_rule" "forticnapp_event_rule" {
  name           = var.event_rule_name
  event_bus_name = aws_cloudwatch_event_bus.forticnapp_event_bus.name
  event_pattern  = jsonencode({ account = var.publisher_account_ids })
}

resource "aws_cloudwatch_event_target" "forticnapp_lambda_target" {
  rule           = aws_cloudwatch_event_rule.forticnapp_event_rule.name
  event_bus_name = aws_cloudwatch_event_bus.forticnapp_event_bus.name
  arn            = aws_lambda_function.forticnapp_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forticnapp_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.forticnapp_event_rule.arn
}

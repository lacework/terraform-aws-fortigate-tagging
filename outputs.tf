output "event_bus_arn" {
  description = "ARN to enter when creating the FortiCNAPP Amazon CloudWatch alert channel."
  value       = aws_cloudwatch_event_bus.forticnapp_event_bus.arn
}

output "event_rule_arn" {
  description = "ARN of the EventBridge rule that routes alerts to the Lambda."
  value       = aws_cloudwatch_event_rule.forticnapp_event_rule.arn
}

output "lambda_function_name" {
  description = "Name of the tagging Lambda function."
  value       = aws_lambda_function.forticnapp_lambda.function_name
}

output "lambda_log_group_name" {
  description = "CloudWatch log group to check when an instance is not tagged."
  value       = aws_cloudwatch_log_group.forticnapp_lambda.name
}

output "tag_filter" {
  description = "Tag filter to configure on the FortiGate dynamic address object."
  value       = "${var.tag_key}=true"
}

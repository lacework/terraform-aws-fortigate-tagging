variable "aws_region" {
  default = "us-east-1"
}

variable "lambda_zip_file" {
  default = "lambda_function-v0.zip"
}

variable "lambda_function_name" {
  default = "forticnapp_lambda"
}

variable "event_bus_name" {
  default = "forticnapp-event-bus"
}

variable "event_rule_name" {
  default = "forticnapp-event-bus-rule"
}

variable "lambda_execution_role_name" {
  default = "forticnapp_lambda_role"
}

variable "tag_key" {
  default = "fcnappalert"
}

variable "publisher_account_ids" {
  description = "AWS account IDs that FortiCNAPP publishes alerts from. Override if your FortiCNAPP environment publishes from a different account."
  type        = list(string)
  default     = ["434813966438"]
}

# FortiCNAPP to FortiGate automated tag-based enforcement (AWS)

Terraform configuration and AWS Lambda function that turn a FortiCNAPP alert into
enforcement on a FortiGate.

When FortiCNAPP raises an alert, it is delivered to an EventBridge custom event
bus. A rule on that bus invokes a Lambda function, which extracts the EC2
instance ID from the alert payload and tags the instance. The FortiGate AWS SDN
connector resolves that tag into a dynamic address object, and your firewall
policy acts on it.

```
FortiCNAPP alert
  -> Amazon CloudWatch alert channel
  -> EventBridge event bus (forticnapp-event-bus)
  -> EventBridge rule -> Lambda (forticnapp_lambda)
  -> ec2:CreateTags  fcnappalert=true
  -> FortiGate SDN connector dynamic address (Tag.fcnappalert=true)
  -> firewall policy
```

Administrator documentation:
[Automated tag-based enforcement using AWS EventBridge and Lambda](https://docs.fortinet.com/document/forticnapp/latest/administration-guide/847234/automated-tag-based-enforcement-using-aws-eventbridge-and-lambda)

## Requirements

- Terraform and the AWS provider
- A FortiCNAPP tenant with alerting enabled
- A FortiGate on a firmware version with AWS SDN connector support
- An AWS account with EC2 workloads, and permissions to create EventBridge,
  Lambda and IAM resources

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # set aws_region
terraform init
terraform apply
```

Then:

1. Create a FortiCNAPP alert channel with **Amazon CloudWatch** as the
   destination, using the `event_bus_arn` output.
2. Create an alert rule bound to that channel.
3. On the FortiGate, create a dynamic address object filtered by the
   `tag_filter` output (`fcnappalert=true` by default) and reference it from a
   policy.

The configuration attaches a resource policy to the event bus that allows the
FortiCNAPP publishing account to deliver events to it, so the manual policy step
described under *Amazon EventBridge Alert Channel > Creating an event bus* in the
administration guide is not needed here. Without that policy the alert channel
test still reports success, but no event is ever delivered.

### Deploying to more than one region

The Lambda tags instances only in its own region, and event buses are regional,
so a customer with workloads in several regions deploys this configuration once
per region. IAM names are global: override `lambda_execution_role_name` and
`tagging_policy_name` with region-specific values for every deployment after the
first, or the second `terraform apply` fails with `EntityAlreadyExists`.

The tag key is configurable via `tag_key`. **It must match the tag filter
configured on the FortiGate dynamic address object** - if the two differ, the
dynamic address never resolves and the policy silently never matches.

## Inputs

| Variable | Description | Default |
| --- | --- | --- |
| `aws_region` | AWS region for the bus, rule and Lambda | `us-east-1` |
| `lambda_zip_file` | Lambda deployment package | `lambda_function-v0.zip` |
| `lambda_function_name` | Lambda function name | `forticnapp_lambda` |
| `event_bus_name` | EventBridge custom bus name | `forticnapp-event-bus` |
| `event_rule_name` | EventBridge rule name | `forticnapp-event-bus-rule` |
| `lambda_execution_role_name` | Lambda IAM role name | `forticnapp_lambda_role` |
| `tag_key` | EC2 tag key applied to the instance | `fcnappalert` |
| `tagging_policy_name` | IAM policy name for ec2:CreateTags (global; see multi-region note) | `forticnapp_lambda_ec2_tagging_policy` |
| `log_retention_days` | Retention for the Lambda's CloudWatch log group | `30` |
| `publisher_account_ids` | FortiCNAPP publishing accounts allowed to publish to the bus and matched by the rule | `["434813966438"]` |

## Outputs

| Output | Description |
| --- | --- |
| `event_bus_arn` | ARN for the FortiCNAPP alert channel |
| `event_rule_arn` | ARN of the EventBridge rule |
| `lambda_function_name` | Name of the tagging Lambda |
| `lambda_log_group_name` | Log group to check when an instance is not tagged |
| `tag_filter` | Tag filter for the FortiGate dynamic address object |

## Known limitation

Tagging depends on the alert payload carrying the EC2 instance ID. Not all alert
types include it. If an instance is not tagged, check the log group named by the
`lambda_log_group_name` output to confirm whether the payload contained an
instance ID.

The function reads the first machine in the alert's entity map, so an alert
referencing several machines results in a single instance being tagged.

## Removing enforcement

Delete the tag from the instance, then wait for the FortiGate SDN connector
refresh interval before confirming the instance has left the dynamic address
group.

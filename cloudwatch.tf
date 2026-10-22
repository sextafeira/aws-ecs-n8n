resource "aws_cloudwatch_log_group" "main" {
  name              = format("/ecs/%s/main", var.project_name)
  retention_in_days = var.log_retention_days

  tags = {
    Name        = format("/ecs/%s/main", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_cloudwatch_log_group" "webhook" {
  name              = format("/ecs/%s/webhook", var.project_name)
  retention_in_days = var.log_retention_days

  tags = {
    Name        = format("/ecs/%s/webhook", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = format("/ecs/%s/worker", var.project_name)
  retention_in_days = var.log_retention_days

  tags = {
    Name        = format("/ecs/%s/worker", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = format("/aws/codebuild/%s", var.project_name)
  retention_in_days = var.log_retention_days

  tags = {
    Name        = format("/aws/codebuild/%s", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

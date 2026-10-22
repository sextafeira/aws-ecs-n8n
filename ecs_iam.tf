resource "aws_iam_role" "ecs_host" {
  name = format("%s-ecs-host", var.project_name)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = format("%s-ecs-host", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_host_ecs" {
  role       = aws_iam_role.ecs_host.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_host_ssm" {
  role       = aws_iam_role.ecs_host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_host" {
  name = format("%s-ecs-host", var.project_name)
  role = aws_iam_role.ecs_host.name

  tags = {
    Name        = format("%s-ecs-host", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_iam_role" "ecs_execution" {
  name = format("%s-ecs-execution", var.project_name)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnLike      = { "aws:SourceArn" = format("arn:%s:ecs:%s:%s:*", data.aws_partition.current.partition, var.region, data.aws_caller_identity.current.account_id) }
      }
    }]
  })

  tags = {
    Name        = format("%s-ecs-execution", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = format("arn:%s:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy", data.aws_partition.current.partition)
}

resource "aws_iam_role_policy" "ecs_secrets" {
  name = "read-n8n-secrets"
  role = aws_iam_role.ecs_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        aws_secretsmanager_secret.encryption_key.arn,
        aws_secretsmanager_secret.valkey_password.arn,
        aws_db_instance.n8n.master_user_secret[0].secret_arn
      ]
    }]
  })
}

# Sem acesso AWS por padrão para o código dos workflows.
resource "aws_iam_role" "ecs_task" {
  name               = format("%s-ecs-task", var.project_name)
  assume_role_policy = aws_iam_role.ecs_execution.assume_role_policy

  tags = {
    Name        = format("%s-ecs-task", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

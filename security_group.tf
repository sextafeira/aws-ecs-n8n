resource "aws_security_group" "alb" {
  name   = format("%s-alb", var.project_name)
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = format("%s-alb", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_security_group" "ecs_host" {
  name   = format("%s-ecs-host", var.project_name)
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = format("%s-ecs-host", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_security_group" "ecs_task" {
  name   = format("%s-ecs-task", var.project_name)
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = format("%s-ecs-task", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_security_group" "rds" {
  name   = format("%s-rds", var.project_name)
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = format("%s-rds", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_security_group" "valkey" {
  name   = format("%s-valkey", var.project_name)
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = format("%s-valkey", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80

  tags = {
    Name        = format("%s-alb-http", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443

  tags = {
    Name        = format("%s-alb-https", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_vpc_security_group_egress_rule" "alb_to_task" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ecs_task.id
  ip_protocol                  = "tcp"
  from_port                    = 5678
  to_port                      = 5678

  tags = {
    Name        = format("%s-alb-to-task", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.ecs_task.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 5678
  to_port                      = 5678

  tags = {
    Name        = format("%s-task-from-alb", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

# Hosts precisam de ECR, SSM, ECS e atualizações. Tasks acessam APIs de workflows.
resource "aws_vpc_security_group_egress_rule" "host_https" {
  security_group_id = aws_security_group.ecs_host.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443

  tags = {
    Name        = format("%s-host-https", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_vpc_security_group_egress_rule" "task_https" {
  security_group_id = aws_security_group.ecs_task.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443

  tags = {
    Name        = format("%s-task-https", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_vpc_security_group_egress_rule" "task_http" {
  security_group_id = aws_security_group.ecs_task.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80

  tags = {
    Name        = format("%s-task-http", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_task" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ecs_task.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432

  tags = {
    Name        = format("%s-rds-from-task", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_vpc_security_group_egress_rule" "task_to_rds" {
  security_group_id            = aws_security_group.ecs_task.id
  referenced_security_group_id = aws_security_group.rds.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432

  tags = {
    Name        = format("%s-task-to-rds", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_vpc_security_group_ingress_rule" "valkey_from_task" {
  security_group_id            = aws_security_group.valkey.id
  referenced_security_group_id = aws_security_group.ecs_task.id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379

  tags = {
    Name        = format("%s-valkey-from-task", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_vpc_security_group_egress_rule" "task_to_valkey" {
  security_group_id            = aws_security_group.ecs_task.id
  referenced_security_group_id = aws_security_group.valkey.id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379

  tags = {
    Name        = format("%s-task-to-valkey", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

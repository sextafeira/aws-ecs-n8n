resource "aws_ecs_service" "main" {
  name                               = format("%s-main", var.project_name)
  cluster                            = aws_ecs_cluster.n8n.id
  task_definition                    = aws_ecs_task_definition.main.arn
  desired_count                      = var.main_count
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  health_check_grace_period_seconds  = 180
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  wait_for_steady_state              = true
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 1
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets         = [aws_subnet.private_subnet_1a.id, aws_subnet.private_subnet_1b.id]
    security_groups = [aws_security_group.ecs_task.id]
  }
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }
  ordered_placement_strategy {
    type  = "binpack"
    field = "memory"
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "n8n"
    container_port   = 5678
  }
  depends_on = [
    aws_ecs_cluster_capacity_providers.n8n,
    aws_lb_listener_rule.webhook,
    aws_vpc_security_group_egress_rule.task_to_rds,
    aws_vpc_security_group_egress_rule.task_to_valkey
  ]

  tags = {
    Name        = format("%s-main", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_ecs_service" "webhook" {
  name                               = format("%s-webhook", var.project_name)
  cluster                            = aws_ecs_cluster.n8n.id
  task_definition                    = aws_ecs_task_definition.webhook.arn
  desired_count                      = var.webhook_count
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 180
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  wait_for_steady_state              = true
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 1
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets         = [aws_subnet.private_subnet_1a.id, aws_subnet.private_subnet_1b.id]
    security_groups = [aws_security_group.ecs_task.id]
  }
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }
  ordered_placement_strategy {
    type  = "binpack"
    field = "memory"
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.webhook.arn
    container_name   = "n8n"
    container_port   = 5678
  }
  depends_on = [
    aws_ecs_cluster_capacity_providers.n8n,
    aws_lb_listener_rule.webhook,
    aws_vpc_security_group_egress_rule.task_to_rds,
    aws_vpc_security_group_egress_rule.task_to_valkey
  ]

  tags = {
    Name        = format("%s-webhook", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_ecs_service" "worker" {
  name                               = format("%s-worker", var.project_name)
  cluster                            = aws_ecs_cluster.n8n.id
  task_definition                    = aws_ecs_task_definition.worker.arn
  desired_count                      = var.worker_count
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  wait_for_steady_state              = true
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 1
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets         = [aws_subnet.private_subnet_1a.id, aws_subnet.private_subnet_1b.id]
    security_groups = [aws_security_group.ecs_task.id]
  }
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }
  ordered_placement_strategy {
    type  = "binpack"
    field = "memory"
  }
  depends_on = [
    aws_ecs_cluster_capacity_providers.n8n,
    aws_lb_listener_rule.webhook,
    aws_vpc_security_group_egress_rule.task_to_rds,
    aws_vpc_security_group_egress_rule.task_to_valkey
  ]

  tags = {
    Name        = format("%s-worker", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

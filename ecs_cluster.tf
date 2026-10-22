resource "aws_ecs_cluster" "n8n" {
  name = var.project_name
  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name        = var.project_name
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_launch_template" "ecs" {
  name          = format("%s-ecs", var.project_name)
  image_id      = data.aws_ssm_parameter.ecs_arm64_ami.value
  instance_type = var.instance_type
  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_host.arn
  }
  vpc_security_group_ids = [aws_security_group.ecs_host.id]
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }
  credit_specification {
    cpu_credits = "standard"
  }
  user_data = base64encode(templatefile("${path.module}/templates/ecs_user_data.sh.tftpl", {
    cluster_name = aws_ecs_cluster.n8n.name
  }))
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = format("%s-ecs", var.project_name)
      Environment = var.environment
      Terraform   = "True"
    }
  }
  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = format("%s-ecs", var.project_name)
      Environment = var.environment
      Terraform   = "True"
    }
  }

  tags = {
    Name        = format("%s-ecs", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_autoscaling_group" "ecs" {
  name                      = format("%s-ecs", var.project_name)
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity
  max_size                  = var.asg_max_size
  vpc_zone_identifier       = [aws_subnet.private_subnet_1a.id, aws_subnet.private_subnet_1b.id]
  health_check_type         = "EC2"
  health_check_grace_period = 300
  protect_from_scale_in     = true
  launch_template {
    id      = aws_launch_template.ecs.id
    version = aws_launch_template.ecs.latest_version
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage       = 100
      max_healthy_percentage       = 150
      scale_in_protected_instances = "Refresh"
    }
  }
  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = format("%s-ecs", var.project_name)
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
  tag {
    key                 = "Terraform"
    value               = "True"
    propagate_at_launch = true
  }
  lifecycle {
    ignore_changes = [desired_capacity]
  }
  depends_on = [aws_route.private_access_1a, aws_route.private_access_1b, aws_iam_role_policy_attachment.ecs_host_ecs, aws_iam_role_policy_attachment.ecs_host_ssm]
}

resource "aws_ecs_capacity_provider" "ec2" {
  name = format("capacity-%s-ec2", var.project_name)
  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "ENABLED"
    managed_draining               = "ENABLED"
    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 2
      instance_warmup_period    = 180
    }
  }

  tags = {
    Name        = format("capacity-%s-ec2", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_ecs_cluster_capacity_providers" "n8n" {
  cluster_name       = aws_ecs_cluster.n8n.name
  capacity_providers = [aws_ecs_capacity_provider.ec2.name]
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 1
  }
}

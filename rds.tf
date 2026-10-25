resource "aws_db_subnet_group" "n8n" {
  name       = format("%s-rds", var.project_name)
  subnet_ids = [aws_subnet.database_subnet_1a.id, aws_subnet.database_subnet_1b.id]

  tags = {
    Name        = format("%s-rds", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_db_parameter_group" "n8n" {
  name   = format("%s-%s", var.project_name, var.db_parameter_group_family)
  family = var.db_parameter_group_family
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = format("%s-%s", var.project_name, var.db_parameter_group_family)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_db_instance" "n8n" {
  identifier                  = var.project_name
  engine                      = "postgres"
  engine_version              = var.postgres_version
  instance_class              = var.instance_class
  allocated_storage           = 20
  max_allocated_storage       = 30
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.n8n.name
  parameter_group_name        = aws_db_parameter_group.n8n.name
  vpc_security_group_ids      = [aws_security_group.rds.id]
  publicly_accessible         = false
  multi_az                    = var.rds_multi_az
  backup_retention_period     = var.rds_backup_retention_period
  backup_window               = "03:00-04:00"
  maintenance_window          = "sun:05:00-sun:06:00"
  auto_minor_version_upgrade  = true
  copy_tags_to_snapshot       = true
  deletion_protection         = var.deletion_protection
  skip_final_snapshot         = true

  tags = {
    Name        = var.project_name
    Environment = var.environment
    Terraform   = "True"
  }
}

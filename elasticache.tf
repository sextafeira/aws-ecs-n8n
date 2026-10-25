resource "aws_elasticache_subnet_group" "n8n" {
  name       = var.project_name
  subnet_ids = [aws_subnet.database_subnet_1a.id, aws_subnet.database_subnet_1b.id]

  tags = {
    Name        = var.project_name
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_elasticache_parameter_group" "n8n" {
  name   = var.project_name
  family = var.cache_parameter_group_family
  parameter {
    name  = "maxmemory-policy"
    value = "noeviction"
  }

  tags = {
    Name        = var.project_name
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_elasticache_replication_group" "n8n" {
  replication_group_id       = var.project_name
  description                = "Fila interna do n8n"
  engine                     = "valkey"
  engine_version             = var.valkey_version
  node_type                  = var.cache_node_type
  num_cache_clusters         = var.cache_node_count
  automatic_failover_enabled = var.cache_automatic_failover
  multi_az_enabled           = var.cache_multi_az
  parameter_group_name       = aws_elasticache_parameter_group.n8n.name
  subnet_group_name          = aws_elasticache_subnet_group.n8n.name
  security_group_ids         = [aws_security_group.valkey.id]
  port                       = 6379
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.valkey_password.result
  auth_token_update_strategy = "ROTATE"
  snapshot_retention_limit   = 1
  snapshot_window            = "03:00-04:00"
  maintenance_window         = "sun:06:00-sun:07:00"
  auto_minor_version_upgrade = true

  tags = {
    Name        = var.project_name
    Environment = var.environment
    Terraform   = "True"
  }
}

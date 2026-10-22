resource "random_password" "encryption_key" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "encryption_key" {
  name                    = format("%s/encryption_key", var.project_name)
  recovery_window_in_days = 0

  tags = {
    Name        = format("%s/encryption_key", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_secretsmanager_secret_version" "encryption_key" {
  secret_id     = aws_secretsmanager_secret.encryption_key.id
  secret_string = random_password.encryption_key.result
}

resource "random_password" "valkey_password" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "valkey_password" {
  name                    = format("%s/valkey_password", var.project_name)
  recovery_window_in_days = 0

  tags = {
    Name        = format("%s/valkey_password", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_secretsmanager_secret_version" "valkey_password" {
  secret_id     = aws_secretsmanager_secret.valkey_password.id
  secret_string = random_password.valkey_password.result
}

resource "aws_ecs_task_definition" "worker" {
  family                   = format("%s-worker", var.project_name)
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }
  container_definitions = jsonencode([
    {
      name         = "n8n"
      image        = format("%s:%s", aws_ecr_repository.n8n.repository_url, var.image_tag)
      command      = ["worker", format("--concurrency=%s", var.worker_concurrency)]
      essential    = true
      cpu          = var.worker_cpu
      memory       = var.worker_memory
      stopTimeout  = 120
      portMappings = [{ containerPort = 5678, hostPort = 5678, protocol = "tcp" }]
      environment = [
        {
          name  = "DB_TYPE"
          value = "postgresdb"
        },
        {
          name  = "DB_POSTGRESDB_HOST"
          value = aws_db_instance.n8n.address
        },
        {
          name  = "DB_POSTGRESDB_PORT"
          value = "5432"
        },
        {
          name  = "DB_POSTGRESDB_DATABASE"
          value = var.db_name
        },
        {
          name  = "DB_POSTGRESDB_USER"
          value = var.db_username
        },
        {
          name  = "DB_POSTGRESDB_SSL_ENABLED"
          value = "true"
        },
        {
          name  = "DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED"
          value = "true"
        },
        {
          name  = "DB_POSTGRESDB_SSL_CA_FILE"
          value = "/opt/certs/global-bundle.pem"
        },
        {
          name  = "EXECUTIONS_MODE"
          value = "queue"
        },
        {
          name  = "QUEUE_BULL_REDIS_HOST"
          value = aws_elasticache_replication_group.n8n.primary_endpoint_address
        },
        {
          name  = "QUEUE_BULL_REDIS_PORT"
          value = "6379"
        },
        {
          name  = "QUEUE_BULL_REDIS_TLS"
          value = "true"
        },
        {
          name  = "QUEUE_HEALTH_CHECK_ACTIVE"
          value = "true"
        },
        {
          name  = "N8N_GRACEFUL_SHUTDOWN_TIMEOUT"
          value = "100"
        },
        {
          name  = "GENERIC_TIMEZONE"
          value = "America/Sao_Paulo"
        },
        {
          name  = "TZ"
          value = "America/Sao_Paulo"
        },
      ]
      secrets = [
        { name = "DB_POSTGRESDB_PASSWORD", valueFrom = format("%s:password::", aws_db_instance.n8n.master_user_secret[0].secret_arn) },
        { name = "N8N_ENCRYPTION_KEY", valueFrom = aws_secretsmanager_secret.encryption_key.arn },
        { name = "QUEUE_BULL_REDIS_PASSWORD", valueFrom = aws_secretsmanager_secret.valkey_password.arn }
      ]
      healthCheck = {
        command     = ["CMD", "node", "-e", "require('http').get('http://127.0.0.1:5678/healthz/readiness',r=>{if(r.statusCode===200){process.exit(0)}process.exit(1)}).on('error',()=>process.exit(1))"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.worker.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "n8n"
        }
      }
      mountPoints    = []
      systemControls = []
      volumesFrom    = []
      linuxParameters = {
        initProcessEnabled = true
        capabilities = {
          add  = []
          drop = ["ALL"]
        }
      }
    }
  ])
  depends_on = [aws_iam_role_policy.ecs_secrets, aws_secretsmanager_secret_version.encryption_key, aws_secretsmanager_secret_version.valkey_password]

  tags = {
    Name        = format("%s-worker", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

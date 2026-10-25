output "n8n_url" {
  value = format("https://%s", var.domain_name)
}

output "alb_dns_name" {
  value = aws_lb.n8n.dns_name
}

output "domain_name_servers" {
  value = aws_route53_zone.n8n.name_servers
}

output "github_connection_arn" {
  value = aws_codeconnections_connection.github.arn
}

output "pipeline_name" {
  value = aws_codepipeline.n8n.name
}

output "ecr_repository_urls" {
  value = {
    n8n = aws_ecr_repository.n8n.repository_url
  }
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.n8n.name
}

output "ecs_service_names" {
  value = {
    main    = aws_ecs_service.main.name
    webhook = aws_ecs_service.webhook.name
    worker  = aws_ecs_service.worker.name
  }
}

output "db_master_secret_arn" {
  value = aws_db_instance.n8n.master_user_secret[0].secret_arn
}

output "asg_name" {
  value = aws_autoscaling_group.ecs.name
}

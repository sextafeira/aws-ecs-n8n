resource "aws_codebuild_project" "n8n" {
  name           = var.project_name
  service_role   = aws_iam_role.codebuild.arn
  build_timeout  = 30
  queued_timeout = 30
  artifacts {
    type = "CODEPIPELINE"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
  environment {
    type                        = "ARM_CONTAINER"
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux-aarch64-standard:3.0"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
    environment_variable {
      name  = "N8N_VERSION"
      value = var.n8n_version
    }
    environment_variable {
      name  = "N8N_REPOSITORY_URI"
      value = aws_ecr_repository.n8n.repository_url
    }
  }
  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild.name
    }
  }
  depends_on = [aws_iam_role_policy.codebuild]

  tags = {
    Name        = var.project_name
    Environment = var.environment
    Terraform   = "True"
  }
}

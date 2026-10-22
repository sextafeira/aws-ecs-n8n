resource "aws_s3_bucket" "artifacts" {
  bucket        = format("%s-artifacts-%s", var.project_name, data.aws_caller_identity.current.account_id)
  force_destroy = true

  tags = {
    Name        = format("%s-artifacts-%s", var.project_name, data.aws_caller_identity.current.account_id)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.artifacts.arn, format("%s/*", aws_s3_bucket.artifacts.arn)]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    id     = "expire-artifacts"
    status = "Enabled"
    filter {}
    expiration {
      days = 30
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_codeconnections_connection" "github" {
  name          = var.project_name
  provider_type = "GitHub"

  tags = {
    Name        = var.project_name
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_codepipeline" "n8n" {
  name           = var.project_name
  role_arn       = aws_iam_role.codepipeline.arn
  pipeline_type  = "V2"
  execution_mode = "QUEUED"
  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifacts.bucket
  }
  stage {
    name = "Source"
    action {
      name             = "GitHub"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      configuration = {
        ConnectionArn    = aws_codeconnections_connection.github.arn
        FullRepositoryId = var.source_repository
        BranchName       = var.source_branch
        DetectChanges    = "true"
      }
    }
  }
  stage {
    name = "Build"
    action {
      name             = "BuildARM64"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.n8n.name
      }
    }
  }
  stage {
    name = "DeployMain"
    action {
      name            = "Main"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BuildArtifact"]
      configuration = {
        ClusterName = aws_ecs_cluster.n8n.name
        ServiceName = aws_ecs_service.main.name
        FileName    = "imagedefinitions-main.json"
      }
    }
  }
  stage {
    name = "DeployProcessing"
    action {
      name            = "Webhook"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BuildArtifact"]
      run_order       = 1
      configuration = {
        ClusterName = aws_ecs_cluster.n8n.name
        ServiceName = aws_ecs_service.webhook.name
        FileName    = "imagedefinitions-webhook.json"
      }
    }
    action {
      name            = "Worker"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BuildArtifact"]
      run_order       = 1
      configuration = {
        ClusterName = aws_ecs_cluster.n8n.name
        ServiceName = aws_ecs_service.worker.name
        FileName    = "imagedefinitions-worker.json"
      }
    }
  }
  depends_on = [aws_iam_role_policy.codepipeline, aws_s3_bucket_versioning.artifacts]

  tags = {
    Name        = var.project_name
    Environment = var.environment
    Terraform   = "True"
  }
}

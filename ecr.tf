resource "aws_ecr_repository" "n8n" {
  name                 = format("%s/n8n", var.project_name)
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = format("%s/n8n", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_ecr_lifecycle_policy" "n8n" {
  repository = aws_ecr_repository.n8n.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Remover imagens sem tag após sete dias"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}

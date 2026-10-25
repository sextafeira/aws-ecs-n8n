resource "aws_route53_zone" "n8n" {
  name = var.dns_zone_name

  tags = {
    Name        = var.dns_zone_name
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_acm_certificate" "n8n" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = format("%s-n8n", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_route53_record" "certificate" {
  zone_id = aws_route53_zone.n8n.zone_id
  name    = one(aws_acm_certificate.n8n.domain_validation_options).resource_record_name
  type    = one(aws_acm_certificate.n8n.domain_validation_options).resource_record_type
  ttl     = 60
  records = [one(aws_acm_certificate.n8n.domain_validation_options).resource_record_value]
}

resource "aws_acm_certificate_validation" "n8n" {
  certificate_arn         = aws_acm_certificate.n8n.arn
  validation_record_fqdns = [aws_route53_record.certificate.fqdn]
}

resource "aws_route53_record" "n8n" {
  zone_id = aws_route53_zone.n8n.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_lb.n8n.dns_name
    zone_id                = aws_lb.n8n.zone_id
    evaluate_target_health = true
  }
}

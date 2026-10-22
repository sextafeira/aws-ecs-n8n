resource "aws_eip" "vpc_eip_1a" {
  domain = "vpc"

  tags = {
    Name        = format("%s-eip-1a", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_nat_gateway" "nat_gateway_1a" {
  allocation_id = aws_eip.vpc_eip_1a.id
  subnet_id     = aws_subnet.public_subnet_1a.id
  depends_on    = [aws_internet_gateway.gw]

  tags = {
    Name        = format("%s-nat-gateway-1a", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_eip" "vpc_eip_1b" {
  domain = "vpc"

  tags = {
    Name        = format("%s-eip-1b", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_nat_gateway" "nat_gateway_1b" {
  allocation_id = aws_eip.vpc_eip_1b.id
  subnet_id     = aws_subnet.public_subnet_1b.id
  depends_on    = [aws_internet_gateway.gw]

  tags = {
    Name        = format("%s-nat-gateway-1b", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

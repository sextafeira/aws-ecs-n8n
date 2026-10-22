resource "aws_subnet" "public_subnet_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.48.0/24"
  availability_zone = format("%sa", var.region)

  tags = {
    Name        = format("%s-public-subnet-1a", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_subnet" "public_subnet_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.49.0/24"
  availability_zone = format("%sb", var.region)

  tags = {
    Name        = format("%s-public-subnet-1b", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_route_table" "public_internet_access" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = format("%s-public-rtb", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_route" "public_access" {
  route_table_id         = aws_route_table.public_internet_access.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_internet_access.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_subnet_1b.id
  route_table_id = aws_route_table.public_internet_access.id
}

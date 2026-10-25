resource "aws_subnet" "database_subnet_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.51.0/24"
  availability_zone = format("%sa", var.region)

  tags = {
    Name        = format("%s-database-subnet-1a", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_subnet" "database_subnet_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.52.0/24"
  availability_zone = format("%sb", var.region)

  tags = {
    Name        = format("%s-database-subnet-1b", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = format("%s-database-rtb", var.project_name)
    Environment = var.environment
    Terraform   = "True"
  }
}

resource "aws_route_table_association" "database_1a" {
  subnet_id      = aws_subnet.database_subnet_1a.id
  route_table_id = aws_route_table.database.id
}

resource "aws_route_table_association" "database_1b" {
  subnet_id      = aws_subnet.database_subnet_1b.id
  route_table_id = aws_route_table.database.id
}

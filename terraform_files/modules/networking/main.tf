# VPC
resource "aws_vpc" "sentryvpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = {
    Name          = "tera-${var.project_name}-vpc"
    Environment   = var.env_type
  }
}

# IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.sentryvpc.id

  tags = {
    Name          = "tera-${var.project_name}-igw"
    Environment   = var.env_type
  }
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.sentryvpc.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name        = "tera-${var.project_name}-public-${each.key}"
    Environment = var.env_type
  }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id                  = aws_vpc.sentryvpc.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az

  tags = {
    Name        = "tera-${var.project_name}-private-${each.key}"
    Environment = var.env_type
  }
}

# Elastic IP
resource "aws_eip" "nat" {
  for_each = var.public_subnets
  domain = "vpc"

  tags = {
    Name        = "tera-${var.project_name}-eip-${each.key}"
    Environment = var.env_type
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  tags = {
    Name        = "tera-${var.project_name}-nat-${each.key}"
    Environment = var.env_type
  }

  depends_on = [aws_internet_gateway.igw]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.sentryvpc.id

  tags = {
    Name        = "tera-${var.project_name}-public-rt"
    Environment = var.env_type
  }
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associations
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table per AZ
resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.sentryvpc.id

  tags = {
    Name        = "tera-${var.project_name}-private-rt-${each.key}"
    Environment = var.env_type
  }
}

resource "aws_route" "private_nat" {
  for_each = aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"

  #Key mapping
  nat_gateway_id = aws_nat_gateway.nat[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# Public SG
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.sentryvpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound for yum / internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "tera-${var.project_name}-public-sg"
    Environment = var.env_type
  }
}

# Public alb SG
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.sentryvpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound for yum / internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "tera-${var.project_name}-alb-sg"
    Environment = var.env_type
  }
}

# Private SG
resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.sentryvpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Outbound for yum / internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "tera-${var.project_name}-private-sg"
    Environment = var.env_type
  }
}

# VPC
output "vpc_id" {
  value = aws_vpc.sentryvpc.id
}

# IGW
output "igw_id" {
  value = aws_internet_gateway.igw.id
}

# NAT Gateway IDs (map)
output "nat_gateway_ids" {
  value = {
    for k, v in aws_nat_gateway.nat : k => v.id
  }
}

# Public Subnet IDs (map)
output "public_subnet_ids" {
  value = {
    for k, v in aws_subnet.public : k => v.id
  }
}

# Private Subnet IDs (map)
output "private_subnet_ids" {
  value = {
    for k, v in aws_subnet.private : k => v.id
  }
}

# Public SG
output "public_sg_id" {
  value = aws_security_group.public_sg.id
}

# Public alb SG
output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

# Private SG
output "private_sg_id" {
  value = aws_security_group.private_sg.id
}

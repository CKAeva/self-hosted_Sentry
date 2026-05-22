# Bastion Outputs
output "bastion_instance_id" {
  description = "Bastion instance ID"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion public IP"
  value       = aws_instance.bastion.public_ip
}

output "bastion_public_dns" {
  description = "Bastion public DNS"
  value       = aws_instance.bastion.public_dns
}

# Private Instance Outputs
output "private_instance_id" {
  description = "Private instance ID"
  value       = aws_instance.private.id
}

output "private_instance_ip" {
  description = "Private instance private IP"
  value       = aws_instance.private.private_ip
}

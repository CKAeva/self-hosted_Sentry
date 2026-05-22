variable "project_name" {
  description = "Project name"
  type        = string
}

variable "env_name" {
  description = "Environment name"
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.env_name)
    error_message = "env_name must be staging or production"
  }
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Map of public subnet IDs"
  type        = map(string)
}

variable "alb_sg_id" {
  description = "ALB security group ID from network module"
  type        = string
}

variable "private_instance_id" {
  description = "Private EC2 instance ID"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

variable "alb_idle_timeout" {
  description = "ALB idle timeout"
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "enable_access_logs" {
  description = "Enable ALB access logs"
  type        = bool
  default     = false
}

variable "host_header" {
  description = "FQDN host header for routing"
  type        = string
}

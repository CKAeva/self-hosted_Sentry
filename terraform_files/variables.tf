variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"

  validation {
    condition = contains([
      "eu-west-3",
      "ap-south-1"
    ], var.region)

    error_message = "Supported regions are eu-west-3 and ap-south-1"
  }
}

variable "env_name" {
  description = "Environment name"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["qa", "staging", "production"], var.env_name)
    error_message = "env_name must be staging or production"
  }
}

variable "project_name" {
  type = string
  default = "sentry"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type = string

  validation {
    condition     = can(regex("^arn:aws:acm:", var.certificate_arn))
    error_message = "certificate_arn must be a valid ACM ARN"
  }
}

variable "host_header" {
  description = "FQDN host header for routing"
  type        = string
}

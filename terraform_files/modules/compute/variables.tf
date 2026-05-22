variable "env_name" {
  description = "Environment name (staging / production)"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["qa", "staging", "production"], var.env_name)
    error_message = "env_name must be either staging or production"
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

# Instance type based on env
variable "instance_type_map" {
  type = map(string)

  default = {
    staging    = "m6a.xlarge"
    production = "m6a.2xlarge"
  }
}

# AMI based on region
variable "ami_map" {
  type = map(string)

  default = {
    "eu-west-3" = "ami-0385589c40dd90fd3"
    "ap-south-1" = "ami-01c68ee746ed2863d"
  }
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 60
}

# Inputs from network module
variable "public_subnet_ids" {
  type = map(string)
}

variable "private_subnet_ids" {
  type = map(string)
}

variable "public_sg_id" {
  type = string
}

variable "private_sg_id" {
  type = string
}

variable "key_name" {
  type = string
  default = "expinternal-key"
}

variable "project_name" {
  type = string
}

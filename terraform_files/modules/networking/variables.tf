variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string

  default = "10.38.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Invalid VPC CIDR format"
  }
}

variable "public_subnets" {
  description = "Map of public subnets with CIDR (/26 only) and AZ"

  type = map(object({
    cidr = string
    az   = string
  }))

  default = {
    az1 = {
      cidr = "10.38.17.0/28"
      az   = "eu-west-3a"
    }
    az2 = {
      cidr = "10.38.17.16/28"
      az   = "eu-west-3b"
    }
  }

  validation {
    condition = alltrue([
      for subnet in var.public_subnets :
      can(cidrhost(subnet.cidr, 0)) &&
      split("/", subnet.cidr)[1] == "28"
    ])
    error_message = "All public subnets must have valid CIDR and /26 prefix"
  }
}

variable "private_subnets" {
  description = "Map of private subnets with CIDR (/26 only) and AZ"

  type = map(object({
    cidr = string
    az   = string
  }))

  default = {
    az1 = {
      cidr = "10.38.17.32/28"
      az   = "eu-west-3a"
    }
    az2 = {
      cidr = "10.38.17.48/28"
      az   = "eu-west-3b"
    }
  }

  validation {
    condition = alltrue([
      for subnet in var.private_subnets :
      can(cidrhost(subnet.cidr, 0)) &&
      split("/", subnet.cidr)[1] == "28"
    ])
    error_message = "All private subnets must have valid CIDR and /26 prefix"
  }
}

variable "project_name" {
  description = "Project name used for tagging resources"
  type        = string

  default = "sentry"
}

variable "env_type" {
  description = "Project enviroment type"
  type        = string

  default = "staging"

  validation {
    condition = contains([
      "qa", "staging", "production"
    ], var.env_type)
    error_message = "Environment type must be tagged with the resoure for identification"
  }
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "asia-southeast1"
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  description = "VPC self link for private service access"
  type        = string
}

variable "tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-f1-micro" # Cheapest tier, good for staging
}

variable "db_password" {
  description = "MySQL application user password"
  type        = string
  sensitive   = true
}

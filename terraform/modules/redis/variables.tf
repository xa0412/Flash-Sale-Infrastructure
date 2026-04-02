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
  description = "VPC self link"
  type        = string
}

variable "memory_size_gb" {
  description = "Redis memory in GB"
  type        = number
  default     = 1
}

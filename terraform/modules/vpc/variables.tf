variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the VPC subnets"
  type        = string
  default     = "asia-southeast1" # Singapore — closest to Shopee's primary market
}

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-southeast1"
}

variable "environment" {
  description = "Environment name (staging/prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC self link from the VPC module"
  type        = string
}

variable "subnet_id" {
  description = "Subnet self link from the VPC module"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary IP range name for pods (from VPC module)"
  type        = string
}

variable "services_range_name" {
  description = "Secondary IP range name for services (from VPC module)"
  type        = string
}

variable "machine_type" {
  description = "Node machine type"
  type        = string
  default     = "e2-medium"
}

variable "min_nodes" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}

variable "preemptible" {
  description = "Use preemptible (Spot) nodes to reduce cost"
  type        = bool
  default     = true
}

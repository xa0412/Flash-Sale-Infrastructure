variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-southeast1"
}

variable "db_password" {
  description = "MySQL application user password"
  type        = string
  sensitive   = true
}

variable "notification_email" {
  description = "Email for monitoring alerts"
  type        = string
  default     = ""
}

variable "uptime_check_url" {
  description = "URL for uptime monitoring"
  type        = string
  default     = ""
}

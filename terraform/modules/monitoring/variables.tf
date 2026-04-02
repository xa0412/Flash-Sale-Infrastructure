variable "project_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "notification_email" {
  description = "Email address for alert notifications"
  type        = string
}

variable "uptime_check_url" {
  description = "URL to check for uptime monitoring"
  type        = string
}

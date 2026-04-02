# Monitoring Module
# Provisions GCP Cloud Monitoring alerts and uptime checks.

resource "google_monitoring_notification_channel" "email" {
  display_name = "Flash Sale Alerts (${var.environment})"
  type         = "email"
  labels = {
    email_address = var.notification_email
  }
}

resource "google_monitoring_uptime_check_config" "api" {
  display_name = "Flash Sale API Uptime (${var.environment})"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/health/ready"
    port         = 80
    use_ssl      = false
    validate_ssl = false
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.uptime_check_url
    }
  }
}

resource "google_monitoring_alert_policy" "gke_cpu" {
  display_name = "GKE High CPU (${var.environment})"
  combiner     = "OR"

  conditions {
    display_name = "GKE node CPU > 80%"
    condition_threshold {
      filter          = "resource.type=\"k8s_node\" AND metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]
}

resource "google_monitoring_alert_policy" "pod_restarts" {
  display_name = "GKE Pod Restart Loop (${var.environment})"
  combiner     = "OR"

  conditions {
    display_name = "Pod restart count > 5 in 10 minutes"
    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND metric.type=\"kubernetes.io/container/restart_count\""
      duration        = "600s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]
}

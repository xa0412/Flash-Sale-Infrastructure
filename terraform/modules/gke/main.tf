# GKE Cluster Module
# Provisions a private, VPC-native GKE cluster with Workload Identity.
# - Private cluster: nodes have no public IPs (security best practice)
# - VPC-native: uses alias IP ranges for pod/service IPs (required for Cloud SQL Auth Proxy)
# - Workload Identity: pods authenticate to GCP APIs without service account key files

locals {
  cluster_name = "flash-sale-gke-${var.environment}"
}

resource "google_container_cluster" "main" {
  name     = local.cluster_name
  location = var.region

  # Use a separately managed node pool for better lifecycle management
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.vpc_id
  subnetwork = var.subnet_id

  # VPC-native cluster - uses secondary IP ranges from the VPC module
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private cluster: nodes get no external IPs
  # The master is accessible via the private endpoint
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Keep public endpoint for kubectl access from laptop
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Workload Identity: pods can impersonate GCP service accounts without key files
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Use REGULAR channel: stable releases with automatic upgrades
  release_channel {
    channel = "REGULAR"
  }

  # Enable network policy enforcement (for NetworkPolicy resources)
  network_policy {
    enabled = true
  }
}

resource "google_container_node_pool" "main" {
  name       = "flash-sale-nodes-${var.environment}"
  location   = var.region
  cluster    = google_container_cluster.main.name

  # Autoscaling: scales from min to max based on pending pods
  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }

  node_config {
    machine_type = var.machine_type

    # Preemptible (Spot) nodes: 60-90% cheaper, can be terminated by GCP with 30s notice
    # Fine for staging; use standard nodes in production for SLA guarantees
    preemptible = var.preemptible

    # Workload Identity must be enabled on nodes too
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      environment = var.environment
    }
  }

  management {
    auto_repair  = true  # Auto-repair unhealthy nodes
    auto_upgrade = true  # Auto-upgrade node versions
  }
}

# GCP Service Account for the application pods (used with Workload Identity)
resource "google_service_account" "app" {
  account_id   = "flash-sale-app-${var.environment}"
  display_name = "Flash Sale App SA (${var.environment})"
}

# Grant the app SA permission to connect to Cloud SQL
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Bind the Kubernetes SA (in flash-sale namespace) to the GCP SA
resource "google_service_account_iam_binding" "workload_identity" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[flash-sale/flash-sale-sa]",
  ]
}

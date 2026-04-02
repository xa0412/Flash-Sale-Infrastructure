# VPC Module — Network foundation for Flash Sale Infrastructure
#
# Why a custom VPC instead of the default?
# 1. The default VPC has subnets in ALL regions (wasteful, harder to audit)
# 2. We need specific CIDR ranges for GKE pods/services (secondary ranges)
# 3. Private Google Access lets GKE nodes pull images without public IPs

resource "google_compute_network" "vpc" {
  name                    = "flash-sale-vpc-${var.environment}"
  project                 = var.project_id
  auto_create_subnetworks = false # Manual subnets — we control the CIDR ranges
  routing_mode            = "REGIONAL"
}

# Primary subnet for GKE nodes
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "gke-subnet-${var.environment}"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.0.0.0/20" # 4,094 node IPs — enough for autoscaling

  # GKE requires secondary ranges for pods and services
  # This is how K8s gets its own IP space without conflicting with node IPs
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.4.0.0/14" # 262,142 pod IPs — GKE allocates 256 per node
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.8.0.0/20" # 4,094 service IPs
  }

  private_ip_google_access = true # Nodes can reach Google APIs without public IPs
}

# Cloud Router + NAT — lets private nodes pull images and reach the internet
# without exposing them with public IPs (security best practice)
resource "google_compute_router" "router" {
  name    = "flash-sale-router-${var.environment}"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "flash-sale-nat-${var.environment}"
  project                            = var.project_id
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall — allow internal communication within the VPC
resource "google_compute_firewall" "internal" {
  name    = "allow-internal-${var.environment}"
  project = var.project_id
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"] # All internal RFC1918 traffic
}

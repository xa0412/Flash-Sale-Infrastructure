terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Remote state — in production, this would be a GCS bucket
  # Uncomment and configure when you have the bucket created:
  # backend "gcs" {
  #   bucket = "flash-sale-tfstate-staging"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required GCP APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",        # VPC, firewall, load balancer
    "container.googleapis.com",       # GKE
    "sqladmin.googleapis.com",        # Cloud SQL (MySQL)
    "redis.googleapis.com",           # Memorystore (Redis)
    "monitoring.googleapis.com",      # Cloud Monitoring
    "cloudresourcemanager.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_id  = var.project_id
  region      = var.region
  environment = "staging"

  depends_on = [google_project_service.apis]
}

# GKE Cluster
module "gke" {
  source = "../../modules/gke"

  project_id          = var.project_id
  region              = var.region
  environment         = "staging"
  vpc_id              = module.vpc.vpc_id
  subnet_id           = module.vpc.subnet_id
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name
  preemptible         = true
}

# Cloud SQL (MySQL)
module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id  = var.project_id
  region      = var.region
  environment = "staging"
  vpc_id      = module.vpc.vpc_id
  db_password = var.db_password
}

# Memorystore (Redis)
module "redis" {
  source = "../../modules/redis"

  project_id  = var.project_id
  region      = var.region
  environment = "staging"
  vpc_id      = module.vpc.vpc_id
}

# Monitoring
module "monitoring" {
  source = "../../modules/monitoring"

  project_id         = var.project_id
  environment        = "staging"
  notification_email = var.notification_email
  uptime_check_url   = var.uptime_check_url
}

# Cloud SQL (MySQL) Module
# Provisions a private MySQL 8.0 instance accessible only within the VPC.
# No public IP is assigned - all connections go through private service access.

# Reserve an IP range for Google's managed services (Cloud SQL) to peer into our VPC
resource "google_compute_global_address" "private_ip_range" {
  name          = "flash-sale-sql-ip-${var.environment}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_id
}

# Establish VPC peering between our VPC and Google's managed services network
# This is what allows Cloud SQL to have a private IP in our VPC
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

resource "google_sql_database_instance" "main" {
  name             = "flash-sale-mysql-${var.environment}"
  database_version = "MYSQL_8_0"
  region           = var.region

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = var.tier

    ip_configuration {
      ipv4_enabled    = false       # No public IP
      private_network = var.vpc_id # Connect through private service access
    }

    backup_configuration {
      enabled            = true
      start_time         = "02:00" # Backup at 2am
      binary_log_enabled = true    # Required for point-in-time recovery
    }

    maintenance_window {
      day          = 7 # Sunday
      hour         = 3
      update_track = "stable"
    }
  }

  # Prevent accidental deletion of the database
  deletion_protection = false # Set to true in production
}

resource "google_sql_database" "flashsale" {
  name     = "flashsale"
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "app" {
  name     = "flashsale"
  instance = google_sql_database_instance.main.name
  password = var.db_password
}

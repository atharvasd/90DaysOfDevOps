resource "google_compute_network" "TerraWeek_VPC" {
  name                    = "${local.name_prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "TerraWeek_Public_Subnet" {
  name          = "${local.name_prefix}-subnet"
  network       = google_compute_network.TerraWeek_VPC.id
  ip_cidr_range = var.subnet_cidr
}

resource "google_compute_route" "TerraWeek_Route" {
  name             = "${local.name_prefix}-route"
  network          = google_compute_network.TerraWeek_VPC.id
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"

}

resource "google_compute_firewall" "TerraWeek_Allow_HTTP" {
  name    = "${local.name_prefix}-firewall"
  network = google_compute_network.TerraWeek_VPC.id
  allow {
    protocol = "tcp"
    ports    = var.allowed_ports
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]

}

resource "google_compute_instance" "TerraWeek_Server" {
  name         = "${local.name_prefix}-instance"
  machine_type = var.environment == "prod" ? "e2-small" : "e2-micro"
  zone         = data.google_compute_zones.zones.names[0]
  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian_image.self_link
    }
  }
  network_interface {
    network    = google_compute_network.TerraWeek_VPC.id
    subnetwork = google_compute_subnetwork.TerraWeek_Public_Subnet.id
    access_config {}
  }
  tags = ["web"]
  labels = merge(local.common_labels, {
    name = "${local.name_prefix}-server"
  })
}

data "google_compute_image" "debian_image" {
  family  = "debian-11"
  project = "debian-cloud"
}

data "google_compute_zones" "zones" {
  region = var.region
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_labels = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_storage_bucket" "logs_bucket" {
  name     = "terraweek-import-test-atharvasd"
  location = "ASIA-SOUTH1"
}


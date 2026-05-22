resource "google_compute_network" "TerraWeek-VPC" {
  name                    = "tws2026-demo-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "TerraWeek-Public-Subnet" {
  name          = "tws2026-demo-subnet"
  network       = google_compute_network.TerraWeek-VPC.id
  ip_cidr_range = "10.0.1.0/24"
}

resource "google_compute_route" "TerraWeek-Route" {
  name             = "tws2026-demo-route"
  network          = google_compute_network.TerraWeek-VPC.id
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_firewall" "TerraWeek-Allow-HTTP" {
  name    = "tws2026-demo-firewall"
  network = google_compute_network.TerraWeek-VPC.id
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

resource "google_compute_instance" "TerraWeek-Server" {
  name         = "tws2026-demo-instance"
  machine_type = "e2-micro"
  zone         = "asia-south1-a"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = google_compute_network.TerraWeek-VPC.id
    subnetwork = google_compute_subnetwork.TerraWeek-Public-Subnet.id
    access_config {}
  }
  tags = ["web"]
}
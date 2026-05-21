variable "region" {
  default = "asia-south1"
  type    = string
}
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>5.0"
    }
  }
}

provider "google" {
  project = "project-ef8fde2b-4dce-45eb-9ac"
  region  = var.region
}

resource "google_storage_bucket" "terra_google_storage_bucket" {
  name                        = "terra-twsdemo2026-bucket"
  location                    = "Asia-south1"
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_compute_instance" "terra_google_compute_instance" {
  name         = "terra-twsdemo2026-instance"
  machine_type = "e2-micro"
  zone         = "asia-south1-a"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network = "default"
  }

}
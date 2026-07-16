terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = "terraform2-demoqr8"
  region  = "us-east1"
}

# Import block for the GCS bucket
import {
  to = google_storage_bucket.imported_bucket
  id = "terraform2-demoqr8/ace-import-demo-atharva-terraform2-demoqr8"
}

# Import block for the firewall rule
import {
  to = google_compute_firewall.imported_firewall
  id = "projects/terraform2-demoqr8/global/firewalls/legacy-allow-http"
}

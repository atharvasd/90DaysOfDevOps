# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform
resource "google_compute_firewall" "imported_firewall" {
  description        = null
  destination_ranges = []
  direction          = "INGRESS"
  disabled           = false
  name               = "legacy-allow-http"
  network            = "https://www.googleapis.com/compute/v1/projects/terraform2-demoqr8/global/networks/default"
  priority           = 1000
  project            = "terraform2-demoqr8"
  source_ranges      = ["0.0.0.0/0"]
  target_tags        = ["web"]
  allow {
    ports    = ["80"]
    protocol = "tcp"
  }
}

# __generated__ by Terraform from "terraform2-demoqr8/ace-import-demo-atharva-terraform2-demoqr8"
resource "google_storage_bucket" "imported_bucket" {
  default_event_based_hold    = false
  enable_object_retention     = false
  force_destroy               = false
  labels                      = {}
  location                    = "US-EAST1"
  name                        = "ace-import-demo-atharva-terraform2-demoqr8"
  project                     = "terraform2-demoqr8"
  public_access_prevention    = "inherited"
  requester_pays              = false
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  hierarchical_namespace {
    enabled = false
  }
  soft_delete_policy {
    retention_duration_seconds = 604800
  }
}

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
  region  = "asia-south1"
}
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>5.0"
    }
  }
  backend "gcs" {
    bucket = "terraweek-state-tws-bucket"
    prefix = "dev/terraform.tfstate"
  }
}

provider "google" {
  # project = "project-ef8fde2b-4dce-45eb-9ac"
  # region  = "asia-south1"
  project = var.project_id
  region  = var.region

}

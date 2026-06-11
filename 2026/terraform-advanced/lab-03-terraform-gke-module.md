# Lab 03: Terraform GKE Module — Production Cluster with IaC

**Topic:** Terraform — Provisioning GKE clusters with the official Google module

---

## Overview

The official `terraform-google-modules/kubernetes-engine/google` module is the production-standard way to provision GKE clusters. It encapsulates hundreds of settings into a clean, opinionated interface.

### Key Concepts
- **Google Terraform Modules** — Official, tested Terraform modules maintained by Google Cloud. Cover GKE, VPC, Cloud SQL, IAM, etc.
- **`google_client_config`** — Data source that provides OAuth2 access tokens. Used to authenticate the Kubernetes provider (replaces static JSON key files).
- **`initial_node_count`** — Sets the starting number of nodes per zone. Renamed from the deprecated `node_count`.
- **VPC-Native Clusters** — Use secondary IP ranges for Pods and Services. Required for modern GKE features.

---

## 🏗️ Hands-on Tasks

### Task 1: Set Up the Terraform Project

```bash
mkdir terraform-gke && cd terraform-gke
```

### Task 2: Write the VPC Module

```hcl
# vpc.tf
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = var.project_id
  network_name = "gke-network"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = "gke-subnet"
      subnet_ip             = "10.0.0.0/20"
      subnet_region         = var.region
      subnet_private_access = true
    }
  ]

  secondary_ranges = {
    gke-subnet = [
      { range_name = "pods",     ip_cidr_range = "10.4.0.0/14" },
      { range_name = "services", ip_cidr_range = "10.8.0.0/20" },
    ]
  }
}
```

### Task 3: Write the GKE Module

```hcl
# gke.tf
data "google_client_config" "default" {}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 35.0"

  project_id        = var.project_id
  name              = "ace-production-cluster"
  region            = var.region
  zones             = ["${var.region}-b", "${var.region}-c"]
  network           = module.vpc.network_name
  subnetwork        = "gke-subnet"
  ip_range_pods     = "pods"
  ip_range_services = "services"

  # Security
  enable_private_nodes    = true
  master_ipv4_cidr_block  = "172.16.0.0/28"

  # Node pool
  initial_node_count = 1
  remove_default_node_pool = true

  node_pools = [
    {
      name               = "app-pool"
      machine_type       = "e2-standard-2"
      min_count          = 1
      max_count          = 5
      disk_size_gb       = 50
      disk_type          = "pd-balanced"
      auto_repair        = true
      auto_upgrade       = true
      initial_node_count = 2
    }
  ]

  node_pools_labels = {
    all      = { environment = "production" }
    app-pool = { workload = "application" }
  }

  node_pools_tags = {
    all      = ["gke-node"]
    app-pool = ["app-node"]
  }

  depends_on = [module.vpc]
}
```

### Task 4: Configure the Kubernetes Provider

```hcl
# providers.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Modern authentication — uses dynamic OAuth2 tokens (no JSON key files)
provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}
```

### Task 5: Variables and Outputs

```hcl
# variables.tf
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-east1"
}
```

```hcl
# outputs.tf
output "cluster_name" {
  value = module.gke.name
}

output "cluster_endpoint" {
  value     = module.gke.endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = module.gke.ca_certificate
  sensitive = true
}

output "kubectl_command" {
  value = "gcloud container clusters get-credentials ${module.gke.name} --region ${var.region}"
}
```

### Task 6: Deploy

```bash
terraform init
terraform plan -var="project_id=<your-project-id>"
terraform apply -var="project_id=<your-project-id>"

# Connect kubectl
eval $(terraform output -raw kubectl_command)
kubectl get nodes
```

---

## ✅ Verification

```bash
# Verify cluster
terraform state list | grep gke
terraform output cluster_name

# Verify via gcloud
gcloud container clusters list
kubectl get nodes -o wide
```

---

## 🧹 Cleanup

```bash
terraform destroy -var="project_id=<your-project-id>"
```

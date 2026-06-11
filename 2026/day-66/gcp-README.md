# Day 66 -- Provision a GKE Cluster with Terraform Modules

## Task
You built Kubernetes clusters manually in the Kubernetes week. Today you provision one the DevOps way -- fully automated, repeatable, and destroyable with a single command. You will use Terraform registry modules to create a Google Kubernetes Engine (GKE) cluster with a managed node pool, connect kubectl, and deploy a workload.

This is what infrastructure teams do every day in production.

---

## Expected Output
- A running GKE cluster on Google Cloud provisioned entirely through Terraform
- kubectl connected to the cluster with nodes visible
- An Nginx deployment running on the cluster
- A markdown file: `day-66-gke-terraform.md`
- Everything destroyed cleanly after the exercise

---

## Challenge Tasks

### Task 1: Project Setup
Create a new project directory with a proper file structure:

```
terraform-gke/
  providers.tf        # Provider and backend config
  vpc.tf              # VPC module call
  gke.tf              # GKE module call
  variables.tf        # All input variables
  outputs.tf          # Cluster outputs
  terraform.tfvars    # Variable values
```

In `providers.tf`:
1. Pin the Google provider to `~> 5.0` or `~> 6.0`.
2. Pin the Kubernetes provider.
3. Configure your GCP project and region.

**Best Practice GKE Provider Authentication:**
To prevent authentication failures and token expiration issues, always configure the `kubernetes` provider dynamically using GKE cluster outputs and a Google client config data source:

```hcl
terraform {
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

# Read active gcloud client config
data "google_client_config" "default" {}

# Dynamically authenticate to GKE
provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}
```

In `variables.tf`, define:
- `project_id` (string)
- `region` (string, default: `"us-central1"`)
- `cluster_name` (string, default: `"terraweek-gke"`)
- `node_instance_type` (string, default: `"e2-standard-2"`)
- `node_desired_count` (number, default: `2`)

---

### Task 2: Create the VPC with Registry Module
GKE clusters require VPC-native traffic routing. This means we must define secondary IP ranges in our subnets for Kubernetes pods and services, avoiding overlapping networks.

In `vpc.tf`, use the `terraform-google-modules/network/google` module:
1. Network Name: `"gke-vpc"`
2. Set up one subnet in your region.
3. Add **secondary ranges** for GKE Pods and GKE Services:

```hcl
module "vpc" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 9.0"
  project_id   = var.project_id
  network_name = "gke-vpc"

  subnets = [
    {
      subnet_name           = "gke-subnet"
      subnet_ip             = "10.10.0.0/16"
      subnet_region         = var.region
      private_ip_google_access = true
    }
  ]

  secondary_ranges = {
    "gke-subnet" = [
      {
        range_name    = "gke-pods"
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = "gke-services"
        ip_cidr_range = "192.168.64.0/22"
      }
    ]
  }
}
```

Run `terraform init` and `terraform plan` to verify the VPC configuration.

**Document:** What are secondary IP ranges in GCP, and why does GKE VPC-native networking require them?

---

### Task 3: Create the GKE Cluster with Registry Module
In `gke.tf`, use the `terraform-google-modules/kubernetes-engine/google` module:

```hcl
module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google"
  version                    = "~> 30.0"
  project_id                 = var.project_id
  name                       = var.cluster_name
  region                     = var.region
  zones                      = ["${var.region}-a", "${var.region}-b"]
  network                    = module.vpc.network_name
  subnetwork                 = module.vpc.subnets_names[0]
  ip_range_pods              = "gke-pods"
  ip_range_services          = "gke-services"
  http_load_balancing        = true
  horizontal_pod_autoscaling = true
  create_service_account     = true

  node_pools = [
    {
      name               = "gke-node-pool"
      machine_type       = var.node_instance_type
      min_count          = 1
      max_count          = 3
      initial_node_count = var.node_desired_count
      disk_size_gb       = 50
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
    }
  ]
}
```

Run:
```bash
terraform init      # Download the GKE module and dependencies
terraform plan      # Review resources to be created (VPC, subnet, GKE cluster, node pools, service accounts)
```

---

### Task 4: Apply and Connect kubectl
1. Apply the configuration:
```bash
terraform apply
```
*Note: GKE cluster creation usually takes between 5 to 10 minutes.*

2. Add outputs in `outputs.tf`:
```hcl
output "cluster_name" {
  value = module.gke.name
}

output "kubernetes_endpoint" {
  value     = module.gke.endpoint
  sensitive = true
}
```

3. Install the GKE auth plugin (required for GKE 1.26+) and update your kubeconfig:
```bash
# Install the auth plugin
gcloud components install gke-gcloud-auth-plugin

# Get cluster credentials
gcloud container clusters get-credentials terraweek-gke --region us-central1
```

4. Verify:
```bash
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
```

**Verify:** Do you see the GKE nodes in a `Ready` state? Can you see GCP-specific system pods running?

---

### Task 5: Deploy a Workload on the Cluster
1. Create `k8s/nginx-deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-terraweek
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

2. Apply the deployment:
```bash
kubectl apply -f k8s/nginx-deployment.yaml
```

3. Wait for GCP to provision an External IP for the LoadBalancer:
```bash
kubectl get svc nginx-service -w
```

4. Open the external IP in your browser to verify Nginx is accessible.

---

### Task 6: Clean Up and Destroy
To prevent ongoing charges, clean up your resources.

1. Delete Kubernetes resources first (this triggers the deletion of the GCP load balancer resource):
```bash
kubectl delete -f k8s/nginx-deployment.yaml
```

2. Wait for the LoadBalancer to be removed:
```bash
kubectl get svc
```

3. Destroy the infrastructure using Terraform:
```bash
terraform destroy
```

---

## Hints
- GCP labels and tags must be lowercase.
- GKE uses Google Container-Optimized OS (`COS_CONTAINERD`) by default.
- If `kubectl` permissions fail, ensure the GCP user has the **Kubernetes Engine Admin** role.
- Always delete Kubernetes services of type `LoadBalancer` before running `terraform destroy`. Otherwise, GCP might leave orphaned target pools or forwarding rules that block VPC destruction.

---

## Documentation
Create `day-66-gke-terraform.md` with:
- GKE Architecture description (Control Plane, VPC-native network, Node Pools).
- File structure and key code configurations.
- Screenshot of `terraform apply` completing.
- Screenshot of `kubectl get nodes` showing the GKE worker nodes.
- Screenshot of the active Nginx welcome page accessed via the GCP LoadBalancer.
- Explanation of why deleting the LoadBalancer Service is critical before executing `terraform destroy`.

---

## Submission
1. Add `day-66-gke-terraform.md` to `2026/day-66/`
2. Commit and push to your fork.

---

## Learn in Public
Share on LinkedIn: "Provisioned a Google Kubernetes Engine (GKE) cluster with Terraform today! Used official Google Modules to build a VPC-native subnet with secondary ranges for pods/services, configured container-optimized node pools, connected kubectl, and deployed Nginx. Full lifecycle automation."

`#90DaysOfDevOps` `#TerraWeek` `#DevOpsKaJosh` `#TrainWithShubham`

Happy Learning!
**TrainWithShubham**

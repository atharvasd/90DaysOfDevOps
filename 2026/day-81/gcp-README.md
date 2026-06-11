# Day 81 -- Introduction to Google Kubernetes Engine (GKE) with Terraform

## Task
You have been running Kubernetes locally with Kind. That works for learning, but the AI-BankApp needs a production environment -- managed control plane, auto-scaling nodes, persistent Google Cloud Storage/disks, and IAM integration.

Google Kubernetes Engine (GKE) is Google Cloud's managed Kubernetes offering, widely considered the most mature managed Kubernetes service. Today you understand GKE architecture, learn how GKE is provisioned via Terraform, provision a cluster, and connect to it.

---

## Expected Output
- Understanding of GKE architecture (Standard vs Autopilot) and GKE add-ons
- GKE Terraform configurations reviewed and understood
- A running GKE cluster provisioned via Terraform
- kubectl connected to the GKE cluster using `gcloud`
- A markdown file: `day-81-gke-intro.md`

---

## Challenge Tasks

### Task 1: Understand GKE Architecture
Research and write notes on:

1. **What does "managed Kubernetes" mean on GCP?**
   - Google manages the **control plane** (API server, etcd, scheduler, control loop manager).
   - You manage the **data plane** (worker nodes) in GKE Standard, or let Google manage both in GKE Autopilot.
   - Google handles upgrades, security patches, and control plane high availability automatically.

2. **GKE Standard vs. GKE Autopilot:**
   - **GKE Standard** -- You define and manage the VM node pools (machine types, disk sizes, scaling thresholds).
   - **GKE Autopilot** -- Google provisions and sizes the nodes automatically based on your Pods' resource requests (CPU/Memory). You only pay for the running Pods' requests.

3. **Core GKE Concepts:**
   - **VPC-Native Clusters** -- Uses alias IP ranges. Every Pod gets a real VPC IP address from a secondary subnet range, making them directly routable.
   - **Workload Identity Federation** -- The GKE equivalent to AWS IRSA. It securely maps Kubernetes service accounts to GCP IAM service accounts, allowing Pods to access GCP APIs (like Cloud Storage or Cloud SQL) without static credentials.
   - **Node Auto-Provisioning (NAP)** -- Automatically creates node pools with matching machine types when pods require specific resources (e.g. GPUs).

---

### Task 2: Study the GKE Terraform Configuration
Imagine a GKE-native configuration in a directory like `terraform/`:

```
argocd.tf           # ArgoCD Helm release
gke.tf              # GKE cluster + Node Pool + Workload Identity
outputs.tf          # Cluster info and helper commands
provider.tf         # Google + Helm + Kubernetes providers
terraform.tfvars    # Default variable values
variables.tf        # Input variables
vpc.tf              # VPC network with subnets & secondary ranges
```

**Analyze the components and compare them to AWS:**

*   **`vpc.tf`**: Unlike AWS, which requires public, private, and database subnets across AZs, GCP uses a global VPC network. We create a single regional subnet with **secondary IP ranges** designated for GKE Pods and GKE Services. GKE connects directly to these ranges.
*   **`gke.tf`**: Uses the official `terraform-google-modules/kubernetes-engine/google` registry module. It sets up the control plane, enables Workload Identity, and configures a node pool with `e2-standard-2` or `e2-medium` instances.
*   **`provider.tf`**: Authenticates the Google provider. Crucially, it dynamically authenticates the `kubernetes` and `helm` providers using an active `google_client_config` data source access token:
    ```hcl
    data "google_client_config" "default" {}
    provider "kubernetes" {
      host                   = "https://${module.gke.endpoint}"
      token                  = data.google_client_config.default.access_token
      cluster_ca_certificate = base64decode(module.gke.ca_certificate)
    }
    ```
*   **`argocd.tf`**: Deploys ArgoCD to the cluster using the Helm provider once GKE completes provisioning.

**Document:** Draw the architecture: GCP VPC -> GKE Control Plane -> Managed Node Pool -> VPC-Native Pod IPs.

---

### Task 3: Provision the GKE Cluster
Verify you have the required CLI tools installed:
```bash
terraform --version
gcloud --version
kubectl version --client
helm version
```

1. Authenticate your terminal session with GCP:
```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <your-project-id>
```

2. Initialize and plan:
```bash
cd terraform
terraform init
terraform plan
```
Review the plan. It will create:
- 1 VPC network and 1 regional subnet with secondary ranges
- 1 GKE cluster control plane
- 1 Node Pool (e.g., 3x `e2-standard-2` nodes)
- IAM roles and Service Accounts for GKE Workload Identity
- ArgoCD Helm release

3. Apply:
```bash
terraform apply
```
*Note: GKE creation takes around 6 to 9 minutes.*

---

### Task 4: Connect to Your Cluster
1. Install the GKE auth plugin (required for GKE 1.26+) and authenticate `kubectl` with the GKE cluster:
```bash
# Install the auth plugin
gcloud components install gke-gcloud-auth-plugin

# Get cluster credentials
gcloud container clusters get-credentials bankapp-gke --region us-central1
```

2. Verify the connection:
```bash
# Check current context
kubectl config current-context

# Cluster info
kubectl cluster-info

# List nodes
kubectl get nodes -o wide
```
You should see GKE nodes running Container-Optimized OS (`COS_CONTAINERD`).

3. Explore GKE-specific system components:
```bash
kubectl get pods -n kube-system
```
Look for `gke-metadata-server` (handles Workload Identity credentials) and `konnectivity-agent` (manages control-plane-to-node communication).

4. Access ArgoCD:
Retrieve the initial admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
Retrieve the ArgoCD LoadBalancer external IP:
```bash
kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

---

### Task 5: Deploy the AI-BankApp Manually
Before using GitOps, deploy the app manually to validate storage and networking.

1. Apply the application manifests:
```bash
cd ..
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/pv.yml
kubectl apply -f k8s/pvc.yml
kubectl apply -f k8s/configmap.yml
kubectl apply -f k8s/secrets.yml
kubectl apply -f k8s/mysql-deployment.yml
kubectl apply -f k8s/service.yml
kubectl apply -f k8s/ollama-deployment.yml
kubectl apply -f k8s/bankapp-deployment.yml
kubectl apply -f k8s/hpa.yml
```

2. Watch the pods:
```bash
kubectl get pods -n bankapp -w
```
Wait for MySQL to start, Ollama to download the LLM model (~2-5 minutes), and the BankApp to become ready.

3. Verify Persistent Volumes on GCP:
```bash
kubectl get pvc -n bankapp
kubectl get pv
```
The volumes are automatically backed by GCP Compute Engine Persistent Disks (`pd-standard` or `pd-balanced`).

4. Verify application access:
```bash
kubectl port-forward svc/bankapp-service -n bankapp 8080:8080
```
Open `http://localhost:8080` in your browser. Register, login, and verify the AI chatbot is working.

---

### Task 6: Understand GKE Costs and Clean Up Strategy
GKE is a premium cloud service. Familiarize yourself with the costs:

| Component | Cost (approximate) |
|-----------|-------------------|
| GKE Control Plane | $0.10/hour (~$73/month) *(Note: GCP offers one free zonal cluster per billing account)* |
| e2-standard-2 nodes (3x) | ~$0.067/hour each (~$146/month total) |
| LoadBalancer (ArgoCD) | ~$0.025/hour (~$18/month) |
| Persistent Disks (15Gi total)| ~$1.20/month |
| **Total for this lab** | **~$238/month (~$8/day)** |

**Important:** Do NOT leave your cluster running overnight.

To clean up the deployment (keeping the cluster for Day 82-83):
```bash
kubectl delete -f k8s/hpa.yml
kubectl delete -f k8s/bankapp-deployment.yml
kubectl delete -f k8s/ollama-deployment.yml
kubectl delete -f k8s/mysql-deployment.yml
kubectl delete -f k8s/service.yml
kubectl delete -f k8s/secrets.yml
kubectl delete -f k8s/configmap.yml
kubectl delete -f k8s/pvc.yml
kubectl delete -f k8s/pv.yml
kubectl delete -f k8s/namespace.yml
```

To destroy the entire infrastructure:
```bash
cd terraform
terraform destroy
```

---

## Hints
- Unlike EKS which uses VPC CNI to assign secondary subnet IPs directly, GKE uses native VPC-native traffic routing which achieves the same directly with alias IPs.
- Under GKE, Workload Identity is the standard for service accounts. The default K8s service account in GKE doesn't have permissions unless bound to a GCP IAM Service Account.
- If `terraform destroy` hangs, check if Kubernetes-created LoadBalancers are blocking network destruction. Delete the Services first.

---

## Documentation
Create `day-81-gke-intro.md` with:
- GKE Architecture diagram (Control Plane, Node Pools, VPC network structure).
- Terraform configuration files explained in your own words.
- Screenshot of `kubectl get nodes` showing GKE instances.
- Screenshot of the system pods in `kube-system` namespace.
- Screenshot of the AI-BankApp login page running via port-forwarding.
- GKE cost breakdown table.

---

## Submission
1. Add `day-81-gke-intro.md` to `2026/day-81/`
2. Commit and push to your fork.

---

## Learn in Public
Share on LinkedIn: "Provisioned a Google Kubernetes Engine (GKE) cluster using Terraform today! Set up VPC-native networking, enabled GKE Workload Identity, deployed the AI-BankApp with MySQL and Ollama, and verified GCP Persistent Disks in action. GKE is smooth!"

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`

Happy Learning!
**TrainWithShubham**

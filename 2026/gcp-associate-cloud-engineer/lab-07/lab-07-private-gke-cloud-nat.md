# Lab 07: Private GKE Clusters and Cloud NAT

**Exam Domain:** Advanced — Production Security

---

## Overview

In production, GKE worker nodes should **never** have public IP addresses. Private clusters isolate nodes from the internet while Cloud NAT provides controlled outbound access for downloading container images and package dependencies.

### Key Concepts
- **Private Clusters** — Nodes get only private IPs. The control plane can also be private.
- **`--enable-private-nodes`** — Removes external IPs from worker nodes.
- **`--master-ipv4-cidr`** — Assigns a private /28 CIDR range to the GKE control plane.
- **Cloud Router + Cloud NAT** — Provides outbound-only internet access for private VMs/nodes. No inbound access from the internet.
- **Private Google Access** — Allows VMs with only private IPs to reach Google APIs (Cloud Storage, Artifact Registry, etc.) without NAT.

---

## 🔒 Hands-on Tasks

### Task 1: Create VPC and Enable Private Google Access

```bash
# Create custom VPC
gcloud compute networks create private-gke-vpc --subnet-mode=custom

# Create subnet
gcloud compute networks subnets create private-gke-subnet \
    --network=private-gke-vpc \
    --region=us-east1 \
    --range=10.0.1.0/24 \
    --enable-private-ip-google-access \
    --secondary-range=pods=10.4.0.0/14,services=10.8.0.0/20
```

### Task 2: Provision Cloud Router and Cloud NAT

```bash
# Create Cloud Router
gcloud compute routers create gke-router \
    --network=private-gke-vpc \
    --region=us-east1

# Create Cloud NAT gateway
gcloud compute routers nats create gke-nat-gateway \
    --router=gke-router \
    --region=us-east1 \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges
```

### Task 3: Deploy a Private GKE Cluster

```bash
gcloud container clusters create ace-private-cluster \
    --region=us-east1 \
    --node-locations=us-east1-b \
    --num-nodes=1 \
    --network=private-gke-vpc \
    --subnetwork=private-gke-subnet \
    --cluster-secondary-range-name=pods \
    --services-secondary-range-name=services \
    --enable-private-nodes \
    --enable-master-authorized-networks \
    --master-authorized-networks=$(curl -s ifconfig.me)/32 \
    --master-ipv4-cidr=172.16.0.0/28 \
    --enable-ip-alias

# Get credentials
gcloud container clusters get-credentials ace-private-cluster \
    --region=us-east1
```

### Task 4: Verify Private Connectivity

```bash
# Verify nodes have NO external IPs
kubectl get nodes -o wide
# The EXTERNAL-IP column should be <none>

# Deploy a test pod and verify outbound connectivity via Cloud NAT
kubectl run test-connectivity --image=busybox --restart=Never \
    --command -- wget -qO- --timeout=10 https://www.google.com

# Check pod logs
kubectl logs test-connectivity

# Clean up test pod
kubectl delete pod test-connectivity
```

---

## ✅ Verification

```bash
# Verify cluster is private
gcloud container clusters describe ace-private-cluster \
    --region=us-east1 \
    --format="yaml(privateClusterConfig)"

# Verify Cloud NAT is active
gcloud compute routers nats describe gke-nat-gateway \
    --router=gke-router --region=us-east1

# Verify nodes have private IPs only
gcloud compute instances list \
    --filter="name~ace-private" \
    --format="table(name, networkInterfaces[0].networkIP, networkInterfaces[0].accessConfigs[0].natIP)"
```

---

## 🧹 Cleanup

```bash
gcloud container clusters delete ace-private-cluster --region=us-east1 --quiet
gcloud compute routers nats delete gke-nat-gateway --router=gke-router --region=us-east1 --quiet
gcloud compute routers delete gke-router --region=us-east1 --quiet
gcloud compute networks subnets delete private-gke-subnet --region=us-east1 --quiet
gcloud compute networks delete private-gke-vpc --quiet
```

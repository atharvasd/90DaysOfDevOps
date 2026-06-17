# Lab 03: Google Kubernetes Engine (GKE) Deployments

**Exam Domain:** 3 — Deploying and implementing a cloud solution | 4 — Ensuring successful operation

---

## Overview

Google Kubernetes Engine (GKE) is Google Cloud's managed Kubernetes service. It handles the control plane, upgrades, and node management so you can focus on deploying workloads.

### Key Concepts
- **GKE Autopilot** — Fully managed. Google manages nodes, scaling, and security. You only define Pods. Recommended for most production apps.
- **GKE Standard** — You manage node pools, machine types, and scaling policies. More control but more responsibility.
- **kubectl** — The Kubernetes CLI. You use it to deploy, inspect, and manage workloads after connecting to a cluster.
- **HPA (Horizontal Pod Autoscaler)** — Automatically scales the number of Pod replicas based on CPU/memory utilization.
- **GKE Auth Plugin** — Modern authentication method (replaces deprecated `gcloud container clusters get-credentials` token injection).

---

## ☸️ Hands-on Tasks

### Task 1: Deploy GKE Clusters

```bash
# GKE Autopilot (Recommended for production apps)
gcloud container clusters create-auto ace-autopilot-cluster \
    --region=us-east1

# GKE Standard (For control over node sizes)
gcloud container clusters create ace-standard-cluster \
    --num-nodes=3 \
    --machine-type=e2-medium \
    --zone=us-east1-b \
    --enable-ip-alias
```

### Task 2: Configure kubectl Credentials

```bash
# Install GKE auth plugin (modern authentication)
gcloud components install gke-gcloud-auth-plugin

# Verify installation
gke-gcloud-auth-plugin --version

# Get credentials for the standard cluster
gcloud container clusters get-credentials ace-standard-cluster \
    --zone=us-east1-b

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Task 3: Deploy a Kubernetes Workload

```bash
# Create deployment
kubectl create deployment web-app --image=nginx:alpine --replicas=3

# Expose as a Service (creates a GCP Network Load Balancer)
kubectl expose deployment web-app \
    --port=80 --target-port=80 --type=LoadBalancer

# Watch for external IP assignment
kubectl get services -w
```

### Task 4: Configure Horizontal Pod Autoscaler (HPA)

```bash
# Set resource requests on the deployment (required for HPA)
kubectl set resources deployment web-app \
    --requests=cpu=50m,memory=64Mi \
    --limits=cpu=200m,memory=128Mi

# Create HPA (scale between 3 and 10 replicas at 50% CPU)
kubectl autoscale deployment web-app \
    --min=3 --max=10 --cpu-percent=50

# Check HPA status
kubectl get hpa web-app
```

### Task 5: Rolling Updates and Rollbacks

```bash
# Update the deployment image (triggers rolling update)
kubectl set image deployment/web-app nginx=nginx:latest

# Watch the rollout
kubectl rollout status deployment/web-app

# View rollout history
kubectl rollout history deployment/web-app

# Rollback to previous version if needed
kubectl rollout undo deployment/web-app
```

---

## ✅ Verification

```bash
# Verify the deployment
kubectl get deployments
kubectl get pods -o wide

# Get the external IP and test
EXTERNAL_IP=$(kubectl get svc web-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$EXTERNAL_IP

# Verify HPA
kubectl describe hpa web-app
```

---

## 🧹 Cleanup

```bash
kubectl delete service web-app
kubectl delete deployment web-app
gcloud container clusters delete ace-standard-cluster --zone=us-east1-b --quiet
gcloud container clusters delete ace-autopilot-cluster --region=us-east1 --quiet
```

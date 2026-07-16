# Lab 03 Concepts: Google Kubernetes Engine (GKE) Deployments

## 1. Google Kubernetes Engine (GKE) Overview
GKE is a managed environment for deploying, managing, and scaling your containerized applications using Google infrastructure. When you use GKE, Google manages the Kubernetes control plane (the master nodes) for you, ensuring high availability and automatic upgrades.

## 2. Cluster Types
GCP offers two modes of operation for GKE clusters:

### GKE Autopilot (Recommended)
- **Fully Managed:** Google manages the entire cluster's infrastructure, including nodes and node pools.
- **Pay-per-pod:** You only pay for the CPU, memory, and storage resources that your Pods actually request, rather than paying for the underlying VMs.
- **Security:** Hardened by default. Google handles all node security patching.

### GKE Standard
- **Node Management:** You are responsible for managing the underlying Compute Engine VMs (Nodes) that your cluster runs on. You choose the machine types, disk sizes, and manage node scaling.
- **Pay-per-node:** You pay for the VMs, regardless of whether they are running Pods or sitting idle.

## 3. Kubernetes Objects
- **Deployment:** A blueprint that dictates how many copies (replicas) of your application should be running. If a Pod crashes, the Deployment controller automatically spins up a new one to replace it.
- **Service:** An abstraction that provides a stable IP address to access your Pods. When you create a Service of type `LoadBalancer` in GKE, Google automatically provisions a physical Cloud Load Balancer in your GCP project to route internet traffic to your application.
- **Horizontal Pod Autoscaler (HPA):** A mechanism that automatically scales the number of Pods in a deployment up or down based on observed CPU or memory utilization.

## 4. Authentication
To interact with your cluster using the `kubectl` command-line tool, you must configure authentication. Historically, this was done natively via `gcloud`, but GCP now requires the **GKE Auth Plugin** (`gke-gcloud-auth-plugin`) to securely generate tokens for `kubectl`.

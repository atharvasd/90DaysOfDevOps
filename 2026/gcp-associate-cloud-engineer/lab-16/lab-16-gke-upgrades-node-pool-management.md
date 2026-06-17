# Lab 16: GKE Cluster Upgrades and Node Pool Management

**Exam Domain:** 4 — Ensuring successful operation of a cloud solution

---

## Overview

GKE clusters require regular upgrades for security patches, new features, and to stay within the supported version window. Understanding how to safely upgrade the control plane, manage node pools, and configure maintenance windows is essential for production operations.

### Key Concepts
- **Control Plane Upgrade** — Must be upgraded before node pools. GKE handles this automatically in Autopilot mode. In Standard mode, you trigger it manually.
- **Node Pool** — A group of nodes with the same configuration. You can run multiple pools with different machine types.
- **Surge Upgrades** — GKE creates extra nodes during upgrades to avoid capacity loss. Configured via `--max-surge-upgrade` and `--max-unavailable-upgrade`.
- **Cordon** — Marks a node as unschedulable (no new Pods). Existing Pods continue running.
- **Drain** — Evicts all Pods from a node, respecting PodDisruptionBudgets.
- **Maintenance Windows** — Scheduled time periods when GKE can perform automatic upgrades.
- **Release Channels** — `rapid`, `regular`, `stable`. Controls how quickly your cluster receives new GKE versions.

---

## 🔄 Hands-on Tasks

### Task 1: Check Available GKE Versions

```bash
# List valid master and node versions
gcloud container get-server-config --zone=us-east1-b \
    --format="yaml(validMasterVersions,validNodeVersions)" | head -30

# Check current cluster version
gcloud container clusters describe ace-standard-cluster \
    --zone=us-east1-b \
    --format="table(currentMasterVersion, currentNodeVersion, releaseChannel)"
```

### Task 2: Upgrade the Control Plane

```bash
# Upgrade to a specific version
gcloud container clusters upgrade ace-standard-cluster \
    --zone=us-east1-b \
    --master \
    --cluster-version=<TARGET_VERSION>

# Monitor upgrade progress
gcloud container operations list \
    --filter="targetLink~ace-standard-cluster AND operationType=UPGRADE_MASTER" \
    --format="table(name, status, startTime)"
```

### Task 3: Add a New Node Pool

```bash
# Create a high-memory node pool with autoscaling
gcloud container node-pools create high-mem-pool \
    --cluster=ace-standard-cluster \
    --zone=us-east1-b \
    --machine-type=e2-standard-4 \
    --num-nodes=1 \
    --enable-autoscaling \
    --min-nodes=1 --max-nodes=3 \
    --max-surge-upgrade=1 \
    --max-unavailable-upgrade=0

# List all node pools
gcloud container node-pools list \
    --cluster=ace-standard-cluster --zone=us-east1-b
```

### Task 4: Migrate Workloads and Remove Old Node Pool

```bash
# Cordon old pool nodes (prevent new scheduling)
for NODE in $(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o name); do
  kubectl cordon $NODE
  echo "Cordoned: $NODE"
done

# Drain workloads from old nodes (respects PodDisruptionBudgets)
for NODE in $(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o name); do
  kubectl drain $NODE \
      --ignore-daemonsets \
      --delete-emptydir-data \
      --force \
      --grace-period=60
  echo "Drained: $NODE"
done

# Verify all Pods moved to new pool
kubectl get pods -A -o wide

# Delete old node pool
gcloud container node-pools delete default-pool \
    --cluster=ace-standard-cluster \
    --zone=us-east1-b --quiet
```

### Task 5: Configure Maintenance Windows

```bash
# Set a weekend maintenance window (2am-6am Saturday/Sunday)
gcloud container clusters update ace-standard-cluster \
    --zone=us-east1-b \
    --maintenance-window-start=2026-01-01T02:00:00Z \
    --maintenance-window-end=2026-01-01T06:00:00Z \
    --maintenance-window-recurrence="FREQ=WEEKLY;BYDAY=SA,SU"

# Alternatively, set a maintenance exclusion (no upgrades during peak)
gcloud container clusters update ace-standard-cluster \
    --zone=us-east1-b \
    --add-maintenance-exclusion-name=holiday-freeze \
    --add-maintenance-exclusion-start=2026-12-20T00:00:00Z \
    --add-maintenance-exclusion-end=2027-01-05T00:00:00Z
```

### Task 6: Change Release Channel

```bash
# Move cluster to stable channel (slower but more tested releases)
gcloud container clusters update ace-standard-cluster \
    --zone=us-east1-b \
    --release-channel=stable
```

---

## ✅ Verification

```bash
# Verify only new node pool exists
gcloud container node-pools list \
    --cluster=ace-standard-cluster --zone=us-east1-b

# Verify all nodes are from the new pool
kubectl get nodes -o custom-columns=\
'NAME:.metadata.name,POOL:.metadata.labels.cloud\.google\.com/gke-nodepool,VERSION:.status.nodeInfo.kubeletVersion'

# Verify maintenance window
gcloud container clusters describe ace-standard-cluster \
    --zone=us-east1-b --format="yaml(maintenancePolicy)"
```

---

## 🧹 Cleanup

No additional cleanup needed — resources are part of the main cluster lifecycle.

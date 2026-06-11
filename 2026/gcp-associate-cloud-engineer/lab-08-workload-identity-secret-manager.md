# Lab 08: GKE Workload Identity and Secret Manager

**Exam Domain:** Advanced — Keyless Security

---

## Overview

Workload Identity is the recommended way to access GCP services from GKE Pods. It eliminates the need for static JSON key files by mapping Kubernetes Service Accounts (KSA) to GCP IAM Service Accounts (GSA).

### Key Concepts
- **Workload Identity Pool** — A trust relationship between your GKE cluster and GCP IAM. Format: `PROJECT_ID.svc.id.goog`.
- **KSA → GSA Binding** — A Kubernetes Service Account is annotated to impersonate a GCP Service Account.
- **Secret Manager** — GCP's managed secrets service. Stores API keys, passwords, certificates. Supports versioning and automatic rotation.
- **No JSON keys** — With Workload Identity, Pods never need `GOOGLE_APPLICATION_CREDENTIALS` or JSON key files.

---

## 🔑 Hands-on Tasks

### Task 1: Enable Workload Identity on a Cluster

```bash
# Update existing cluster to enable Workload Identity
gcloud container clusters update ace-private-cluster \
    --region=us-east1 \
    --workload-pool=ace-lab-prod-2026.svc.id.goog

# Update node pool to use GKE metadata server
gcloud container node-pools update default-pool \
    --cluster=ace-private-cluster \
    --region=us-east1 \
    --workload-metadata=GKE_METADATA
```

### Task 2: Create a Secret in Secret Manager

```bash
# Create secret metadata
gcloud secrets create db-password \
    --replication-policy="automatic"

# Add secret payload value
echo -n "SuperSecretGCPPassword" | \
    gcloud secrets versions add db-password --data-file=-

# Verify
gcloud secrets versions access latest --secret="db-password"
```

### Task 3: Configure Workload Identity Binding

```bash
# Create GCP IAM Service Account (GSA)
gcloud iam service-accounts create secret-reader-sa \
    --display-name="Secret Reader Service Account"

# Grant GSA access to read secrets
gcloud secrets add-iam-policy-binding db-password \
    --member="serviceAccount:secret-reader-sa@ace-lab-prod-2026.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

# Allow KSA to impersonate GSA
gcloud iam service-accounts add-iam-policy-binding \
    secret-reader-sa@ace-lab-prod-2026.iam.gserviceaccount.com \
    --role="roles/iam.workloadIdentityUser" \
    --member="serviceAccount:ace-lab-prod-2026.svc.id.goog[bankapp/bankapp-ksa]"
```

### Task 4: Create Kubernetes Resources

```bash
# Create namespace
kubectl create namespace bankapp

# Create Kubernetes Service Account (KSA) with GSA annotation
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bankapp-ksa
  namespace: bankapp
  annotations:
    iam.gke.io/gcp-service-account: secret-reader-sa@ace-lab-prod-2026.iam.gserviceaccount.com
EOF
```

### Task 5: Test Secret Access from a Pod

```bash
# Deploy a test pod using the KSA
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-test
  namespace: bankapp
spec:
  serviceAccountName: bankapp-ksa
  containers:
  - name: gcloud
    image: google/cloud-sdk:slim
    command: ["sleep", "3600"]
EOF

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/secret-test -n bankapp --timeout=120s

# Access secret from inside the pod (no JSON key needed!)
kubectl exec -n bankapp secret-test -- \
    gcloud secrets versions access latest --secret="db-password"
# Output: SuperSecretGCPPassword
```

---

## ✅ Verification

```bash
# Verify Workload Identity is enabled
gcloud container clusters describe ace-private-cluster \
    --region=us-east1 --format="yaml(workloadIdentityConfig)"

# Verify KSA annotation
kubectl describe sa bankapp-ksa -n bankapp

# Verify IAM bindings
gcloud iam service-accounts get-iam-policy \
    secret-reader-sa@ace-lab-prod-2026.iam.gserviceaccount.com
```

---

## 🧹 Cleanup

```bash
kubectl delete namespace bankapp
gcloud secrets delete db-password --quiet
gcloud iam service-accounts delete \
    secret-reader-sa@ace-lab-prod-2026.iam.gserviceaccount.com --quiet
```

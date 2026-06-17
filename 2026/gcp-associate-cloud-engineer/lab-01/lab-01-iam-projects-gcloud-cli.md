# Lab 01: IAM, Projects, and gcloud CLI Configuration

**Exam Domain:** 1 — Setting up a cloud solution environment | 5 — Configuring access and security

---

## Overview

IAM (Identity and Access Management) is the backbone of Google Cloud security. Every GCP resource is protected by IAM policies that define *who* can do *what* on *which* resource. The `gcloud` CLI is the primary tool for managing GCP resources from the terminal.

### Key Concepts
- **Projects** are the base unit of organization in GCP. All resources live inside a project.
- **IAM Roles** are collections of permissions. Google provides Predefined Roles (e.g., `roles/storage.objectViewer`) and you can create Custom Roles.
- **Service Accounts** are identities for applications (not humans). They follow the principle of least privilege.
- **gcloud configurations** let you manage multiple project/account profiles from one machine.

---

## 🛠️ Hands-on Tasks

### Task 1: Manage Projects and Billing

```bash
# Create a new testing project
gcloud projects create ace-lab-prod-2026 --name="ACE Lab Production"

# Set active project
gcloud config set project ace-lab-prod-2026

# Link billing account (required to use paid services)
gcloud billing accounts list
gcloud billing projects link ace-lab-prod-2026 \
    --billing-account=<BILLING_ACCOUNT_ID>
```

### Task 2: Manage Multiple gcloud Profiles

```bash
# Create separate CLI configurations for dev and prod
gcloud config configurations create dev-config
gcloud config set project ace-lab-dev-2026

gcloud config configurations create prod-config
gcloud config set project ace-lab-prod-2026

# Switch between configurations
gcloud config configurations activate dev-config

# List all configurations
gcloud config configurations list

# View active configuration details
gcloud config list
```

### Task 3: IAM Service Accounts and Roles

Create a service account with permission to only read Cloud Storage objects but create Compute Engine instances.

```bash
# Create Service Account
gcloud iam service-accounts create ace-deployer \
    --description="SA for deployment tasks" \
    --display-name="ACE Deployer"

# Bind Storage Object Viewer role
gcloud projects add-iam-policy-binding ace-lab-prod-2026 \
    --member="serviceAccount:ace-deployer@ace-lab-prod-2026.iam.gserviceaccount.com" \
    --role="roles/storage.objectViewer"

# Bind Compute Instance Admin role
gcloud projects add-iam-policy-binding ace-lab-prod-2026 \
    --member="serviceAccount:ace-deployer@ace-lab-prod-2026.iam.gserviceaccount.com" \
    --role="roles/compute.instanceAdmin.v1"
```

### Task 4: Create a Custom IAM Role

```bash
# Create a custom role with only specific permissions
gcloud iam roles create customStorageReader \
    --project=ace-lab-prod-2026 \
    --title="Custom Storage Reader" \
    --description="Can only list and get storage objects" \
    --permissions=storage.objects.get,storage.objects.list \
    --stage=GA
```

---

## ✅ Verification

```bash
# Verify service accounts
gcloud iam service-accounts list

# Verify IAM policy bindings
gcloud projects get-iam-policy ace-lab-prod-2026 \
    --flatten="bindings[].members" \
    --filter="bindings.members:ace-deployer" \
    --format="table(bindings.role)"

# Verify custom role
gcloud iam roles describe customStorageReader --project=ace-lab-prod-2026
```

---

## 🧹 Cleanup

```bash
gcloud iam service-accounts delete \
    ace-deployer@ace-lab-prod-2026.iam.gserviceaccount.com --quiet
gcloud iam roles delete customStorageReader --project=ace-lab-prod-2026 --quiet
gcloud projects delete ace-lab-prod-2026 --quiet
```

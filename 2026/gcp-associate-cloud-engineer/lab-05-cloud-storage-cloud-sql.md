# Lab 05: Cloud Storage and Cloud SQL Databases

**Exam Domain:** 2 — Planning and configuring a cloud solution | 3 — Deploying and implementing

---

## Overview

Cloud Storage and Cloud SQL are the two most fundamental data services in GCP. Storage is for unstructured data (files, images, backups) and Cloud SQL is for relational databases.

### Key Concepts
- **Cloud Storage Classes** — Standard (hot), Nearline (monthly access), Coldline (quarterly), Archive (yearly). Use lifecycle policies to auto-transition.
- **Versioning** — Keeps old versions of objects. Essential for backup and compliance.
- **Uniform Bucket-Level Access** — Modern access control model. Replaces legacy ACLs. Recommended for all new buckets.
- **Cloud SQL** — Managed MySQL, PostgreSQL, or SQL Server. Supports automated backups, replicas, and failover.
- **`gcloud storage`** — Modern CLI for storage operations. Replaces the deprecated `gsutil` command.

> ⚠️ **Important:** Always use `gcloud storage` commands instead of `gsutil`. Google is deprecating `gsutil`.

---

## 🗄️ Hands-on Tasks

### Task 1: Cloud Storage Management

```bash
# Create bucket with uniform access (modern standard)
gcloud storage buckets create gs://ace-backup-bucket-<yourname> \
    --location=us-east1 \
    --uniform-bucket-level-access

# Enable versioning
gcloud storage buckets update gs://ace-backup-bucket-<yourname> --versioning

# Upload a file
echo "Hello from GCS" > test-file.txt
gcloud storage cp test-file.txt gs://ace-backup-bucket-<yourname>/

# List objects
gcloud storage ls gs://ace-backup-bucket-<yourname>/

# Download a file
gcloud storage cp gs://ace-backup-bucket-<yourname>/test-file.txt downloaded.txt
```

### Task 2: Set Lifecycle Policy

```bash
# Move objects to Nearline storage after 30 days, delete after 365 days
cat > lifecycle.json << 'EOF'
{
  "rule": [
    {
      "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
      "condition": {"age": 30}
    },
    {
      "action": {"type": "Delete"},
      "condition": {"age": 365}
    }
  ]
}
EOF

gcloud storage buckets update gs://ace-backup-bucket-<yourname> \
    --lifecycle-file=lifecycle.json

# Verify lifecycle policy
gcloud storage buckets describe gs://ace-backup-bucket-<yourname> \
    --format="yaml(lifecycle)"
```

### Task 3: Test Object Versioning

```bash
# Upload v1
echo "Version 1" > versioned.txt
gcloud storage cp versioned.txt gs://ace-backup-bucket-<yourname>/

# Overwrite with v2
echo "Version 2" > versioned.txt
gcloud storage cp versioned.txt gs://ace-backup-bucket-<yourname>/

# List all versions
gcloud storage ls --all-versions gs://ace-backup-bucket-<yourname>/versioned.txt

# Restore v1 (copy old generation to current)
gcloud storage cp gs://ace-backup-bucket-<yourname>/versioned.txt#<GENERATION_NUMBER> \
    gs://ace-backup-bucket-<yourname>/versioned.txt
```

### Task 4: Provision Cloud SQL Database

```bash
# Deploy MySQL 8.0 instance (takes 5-10 minutes)
gcloud sql instances create ace-mysql-db \
    --database-version=MYSQL_8_0 \
    --tier=db-f1-micro \
    --region=us-east1 \
    --root-password="SuperSecurePassword123" \
    --storage-auto-increase \
    --backup-start-time=03:00

# Create a database
gcloud sql databases create app_db --instance=ace-mysql-db

# Create a user
gcloud sql users create app_user \
    --instance=ace-mysql-db \
    --password="AppUserPass123"
```

### Task 5: Connect to Cloud SQL

```bash
# Connect via Cloud SQL Auth Proxy (recommended for secure access)
# Install the proxy
gcloud components install cloud-sql-proxy

# Connect (opens a local port)
cloud-sql-proxy ace-lab-prod-2026:us-east1:ace-mysql-db \
    --port=3306 &

# Connect with mysql client
mysql -h 127.0.0.1 -P 3306 -u app_user -p app_db
```

---

## ✅ Verification

```bash
# Verify bucket
gcloud storage buckets describe gs://ace-backup-bucket-<yourname>

# Verify Cloud SQL
gcloud sql instances list
gcloud sql databases list --instance=ace-mysql-db
```

---

## 🧹 Cleanup

```bash
gcloud sql instances delete ace-mysql-db --quiet
gcloud storage rm -r gs://ace-backup-bucket-<yourname>
```

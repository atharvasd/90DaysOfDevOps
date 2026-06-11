# Lab 06: Cloud Monitoring, Logging, and Audit Trails

**Exam Domain:** 4 — Ensuring successful operation of a cloud solution

---

## Overview

Google Cloud's operations suite (formerly Stackdriver) provides monitoring, logging, and alerting for all GCP resources. Understanding how to query logs, set up alerts, and track operational health is essential for the ACE exam.

### Key Concepts
- **Cloud Logging** — Centralized log management. All GCP services emit logs automatically. Use log filters to query.
- **Cloud Monitoring** — Metrics, dashboards, uptime checks, and alerting.
- **Audit Logs** — Immutable records of who did what, when. Three types: Admin Activity (always on), Data Access (must enable), System Event.
- **Log-based Metrics** — Custom metrics derived from log entries. Used to create alerts from log patterns.
- **Log Sinks** — Export logs to Cloud Storage, BigQuery, or Pub/Sub for long-term analysis.

---

## 📊 Hands-on Tasks

### Task 1: Query Logs with gcloud CLI

```bash
# Read the last 10 compute instance audit logs
gcloud logging read \
    "resource.type=gce_instance AND logName:cloudaudit.googleapis.com" \
    --limit=10 \
    --format="table(timestamp, protoPayload.methodName, protoPayload.authenticationInfo.principalEmail)"

# Read all errors in the last hour
gcloud logging read \
    "severity>=ERROR AND timestamp>=\"$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)\"" \
    --limit=20

# Read GKE cluster logs
gcloud logging read \
    "resource.type=k8s_cluster" \
    --limit=10 --format=json
```

### Task 2: Create Log-based Metrics

```bash
# Create metric that counts VM restarts
gcloud logging metrics create vm-restarts-metric \
    --description="Counts VM restart events" \
    --log-filter="resource.type=gce_instance AND protoPayload.methodName=v1.compute.instances.reset"

# Create metric for 5xx errors in Cloud Run
gcloud logging metrics create cloud-run-5xx-errors \
    --description="Counts 5xx errors in Cloud Run" \
    --log-filter="resource.type=cloud_run_revision AND httpRequest.status>=500"

# List all custom metrics
gcloud logging metrics list
```

### Task 3: Create a Log Sink (Export Logs)

```bash
# Create a storage bucket for log export
gcloud storage buckets create gs://ace-audit-logs-<yourname> \
    --location=us-east1 --uniform-bucket-level-access

# Create a sink to export audit logs to Cloud Storage
gcloud logging sinks create audit-log-sink \
    storage.googleapis.com/ace-audit-logs-<yourname> \
    --log-filter="logName:cloudaudit.googleapis.com"

# Get the sink's service account and grant it write access
SINK_SA=$(gcloud logging sinks describe audit-log-sink --format='value(writerIdentity)')
gcloud storage buckets add-iam-policy-binding gs://ace-audit-logs-<yourname> \
    --member="$SINK_SA" \
    --role="roles/storage.objectCreator"
```

### Task 4: Create Uptime Checks

```bash
# Create an uptime check for a URL (e.g., Cloud Run app)
gcloud monitoring uptime create ace-app-uptime \
    --display-name="ACE Web App Uptime" \
    --resource-type=uptime-url \
    --monitored-resource='{"host": "<YOUR_CLOUD_RUN_URL>", "project_id": "ace-lab-prod-2026"}' \
    --check-type=HTTP \
    --period=300
```

> **Note:** Complex alert policies are easier to manage via the Cloud Console or Terraform. The CLI covers basic cases.

### Task 5: View and Manage Audit Logs

```bash
# List Admin Activity logs (always enabled)
gcloud logging read \
    "logName=projects/ace-lab-prod-2026/logs/cloudaudit.googleapis.com%2Factivity" \
    --limit=5 --format="table(timestamp, protoPayload.methodName)"

# Enable Data Access logs for Cloud Storage
gcloud projects get-iam-policy ace-lab-prod-2026 --format=json > policy.json
# Edit policy.json to add auditLogConfigs for storage.googleapis.com
# Then apply:
# gcloud projects set-iam-policy ace-lab-prod-2026 policy.json
```

---

## ✅ Verification

```bash
# Verify log-based metrics
gcloud logging metrics describe vm-restarts-metric

# Verify sink
gcloud logging sinks list

# Test: Create a VM and check if audit log appears
gcloud compute instances create test-audit-vm \
    --zone=us-east1-b --machine-type=e2-micro \
    --image-family=debian-12 --image-project=debian-cloud
sleep 30
gcloud logging read \
    "resource.type=gce_instance AND protoPayload.methodName=v1.compute.instances.insert" \
    --limit=1
```

---

## 🧹 Cleanup

```bash
gcloud compute instances delete test-audit-vm --zone=us-east1-b --quiet
gcloud logging sinks delete audit-log-sink --quiet
gcloud logging metrics delete vm-restarts-metric --quiet
gcloud logging metrics delete cloud-run-5xx-errors --quiet
gcloud storage rm -r gs://ace-audit-logs-<yourname>
```

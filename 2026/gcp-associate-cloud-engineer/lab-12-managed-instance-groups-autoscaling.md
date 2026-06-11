# Lab 12: Managed Instance Groups, Templates & Autoscaling

**Exam Domain:** 3 — Deploying and implementing | 4 — Ensuring successful operation

---

## Overview

Managed Instance Groups (MIGs) are how GCP runs stateless applications at scale without Kubernetes. They automatically manage VM lifecycle including creation, deletion, auto-healing, and rolling updates.

### Key Concepts
- **Instance Template** — A blueprint defining machine type, boot disk, startup script, tags, and network. Templates are immutable — create a new one to change settings.
- **Managed Instance Group (MIG)** — A group of identical VMs created from a template. MIGs provide autoscaling, auto-healing, and rolling updates.
- **Autoscaling** — Automatically adjusts the number of VMs based on CPU, memory, load balancing metrics, or custom metrics.
- **Auto-Healing** — Uses health checks to detect unhealthy VMs and automatically recreate them.
- **Rolling Updates** — Gradually replace VMs with a new template (canary or full rollout).

---

## 🖥️ Hands-on Tasks

### Task 1: Create an Instance Template

```bash
gcloud compute instance-templates create ace-web-template \
    --machine-type=e2-micro \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --tags=web-server \
    --metadata=startup-script='#!/bin/bash
apt-get update && apt-get install -y apache2
HOSTNAME=$(hostname)
echo "Hello from $HOSTNAME" > /var/www/html/index.html
systemctl start apache2'
```

### Task 2: Create a Managed Instance Group

```bash
gcloud compute instance-groups managed create ace-web-mig \
    --template=ace-web-template \
    --size=2 \
    --zone=us-east1-b
```

### Task 3: Configure Autoscaling

```bash
gcloud compute instance-groups managed set-autoscaling ace-web-mig \
    --zone=us-east1-b \
    --min-num-replicas=2 \
    --max-num-replicas=5 \
    --target-cpu-utilization=0.6 \
    --cool-down-period=60
```

### Task 4: Create a Health Check and Enable Auto-Healing

```bash
# Create health check
gcloud compute health-checks create http ace-web-hc \
    --port=80 \
    --request-path=/

# Attach health check to MIG for auto-healing
gcloud compute instance-groups managed update ace-web-mig \
    --zone=us-east1-b \
    --health-check=ace-web-hc \
    --initial-delay=120
```

### Task 5: Test Auto-Healing

```bash
# List instances in the MIG
gcloud compute instance-groups managed list-instances ace-web-mig \
    --zone=us-east1-b

# Delete one instance (MIG will auto-recreate it)
gcloud compute instances delete <INSTANCE_NAME> --zone=us-east1-b --quiet

# Watch the MIG recreate the instance
watch -n 5 "gcloud compute instance-groups managed list-instances ace-web-mig \
    --zone=us-east1-b"
```

### Task 6: Rolling Update to New Template

```bash
# Create a new template (e.g., updated startup message)
gcloud compute instance-templates create ace-web-template-v2 \
    --machine-type=e2-micro \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --tags=web-server \
    --metadata=startup-script='#!/bin/bash
apt-get update && apt-get install -y apache2
HOSTNAME=$(hostname)
echo "Hello from $HOSTNAME — Version 2" > /var/www/html/index.html
systemctl start apache2'

# Start rolling update (1 VM at a time, 20% max surge)
gcloud compute instance-groups managed rolling-action start-update ace-web-mig \
    --version=template=ace-web-template-v2 \
    --zone=us-east1-b \
    --max-surge=1 \
    --max-unavailable=0

# Monitor the rollout
watch -n 5 "gcloud compute instance-groups managed list-instances ace-web-mig \
    --zone=us-east1-b"
```

---

## ✅ Verification

```bash
# Verify MIG status
gcloud compute instance-groups managed describe ace-web-mig --zone=us-east1-b

# Verify autoscaler
gcloud compute instance-groups managed describe ace-web-mig \
    --zone=us-east1-b --format="yaml(autoscaler)"

# Verify all instances are healthy
gcloud compute instance-groups managed list-instances ace-web-mig \
    --zone=us-east1-b --format="table(instance, status, currentAction)"
```

---

## 🧹 Cleanup

```bash
gcloud compute instance-groups managed delete ace-web-mig --zone=us-east1-b --quiet
gcloud compute instance-templates delete ace-web-template ace-web-template-v2 --quiet
gcloud compute health-checks delete ace-web-hc --quiet
```

# Lab 02: Custom VPC Networks and Compute Engine Instances

**Exam Domain:** 2 — Planning and configuring a cloud solution | 3 — Deploying and implementing a cloud solution

---

## Overview

VPC (Virtual Private Cloud) networks are the foundation of all networking in GCP. Unlike AWS, GCP VPC networks are **global** — subnets are regional but the network spans all regions. Understanding VPC design is critical for the ACE exam and production work.

### Key Concepts
- **Custom Mode VPC** — You define subnets manually (recommended for production).
- **Auto Mode VPC** — GCP auto-creates one subnet per region (good for dev/test only).
- **Firewall Rules** — Stateful rules that control ingress/egress traffic. They use target tags or service accounts.
- **Network Tags** — Labels on VM instances used to apply firewall rules selectively.
- **Startup Scripts** — Bash scripts that run when a VM boots, used to install software automatically.

---

## 🌐 Hands-on Tasks

### Task 1: Create Custom VPC Network

```bash
# Create custom network (no auto subnet generation)
gcloud compute networks create ace-custom-vpc --subnet-mode=custom

# Create Web Subnet in asia-south1
gcloud compute networks subnets create web-subnet \
    --network=ace-custom-vpc \
    --region=asia-south1 \
    --range=10.0.1.0/24

# Create App Subnet in asia-south1
gcloud compute networks subnets create app-subnet \
    --network=ace-custom-vpc \
    --region=asia-south1 \
    --range=10.0.2.0/24
```

### Task 2: Create Firewall Rules

```bash
# Allow ingress HTTP (port 80) only for VMs tagged with 'web-server'
gcloud compute firewall-rules create allow-http-web \
    --network=ace-custom-vpc \
    --allow=tcp:80 \
    --target-tags=web-server \
    --source-ranges=0.0.0.0/0

# Allow SSH (for management)
gcloud compute firewall-rules create allow-ssh \
    --network=ace-custom-vpc \
    --allow=tcp:22 \
    --source-ranges=0.0.0.0/0

# Allow internal communication between subnets
gcloud compute firewall-rules create allow-internal-subnets \
    --network=ace-custom-vpc \
    --allow=tcp,udp,icmp \
    --source-ranges=10.0.1.0/24,10.0.2.0/24
```

### Task 3: Deploy Compute Engine VMs

Create an Apache web server VM in the web subnet using a startup script:

```bash
# Create startup script locally
cat > startup.sh << 'EOF'
#!/bin/bash
apt-get update
apt-get install -y apache2
echo "Hello from GCE Web Server — $(hostname)" > /var/www/html/index.html
systemctl start apache2
EOF

# Deploy VM
gcloud compute instances create web-vm-01 \
    --zone=asia-south1-b \
    --subnet=web-subnet \
    --tags=web-server \
    --metadata-from-file=startup-script=startup.sh \
    --machine-type=e2-micro \
    --image-family=debian-12 \
    --image-project=debian-cloud
```

### Task 4: SSH and Test Connectivity

```bash
# SSH into the VM
gcloud compute ssh web-vm-01 --zone=asia-south1-b

# From inside the VM, verify Apache is running
curl localhost

# From your local machine, test via external IP
EXTERNAL_IP=$(gcloud compute instances describe web-vm-01 \
    --zone=asia-south1-b --format='value(networkInterfaces[0].accessConfigs[0].natIP)')
curl http://$EXTERNAL_IP
```

---

## ✅ Verification

```bash
# List VPC networks
gcloud compute networks list

# List subnets
gcloud compute networks subnets list --network=ace-custom-vpc

# List firewall rules
gcloud compute firewall-rules list --filter="network=ace-custom-vpc"

# Verify VM
gcloud compute instances list --filter="name=web-vm-01"
```

---

## 🧹 Cleanup

```bash
gcloud compute instances delete web-vm-01 --zone=asia-south1-b --quiet
gcloud compute firewall-rules delete allow-http-web allow-ssh allow-internal-subnets --quiet
gcloud compute networks subnets delete web-subnet app-subnet --region=asia-south1 --quiet
gcloud compute networks delete ace-custom-vpc --quiet
```

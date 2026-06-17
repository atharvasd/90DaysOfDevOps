# Lab 14: VPC Peering, Shared VPC & Cloud SQL Private Connectivity

**Exam Domain:** 2 — Planning and configuring | 5 — Configuring access and security

---

## Overview

Enterprise GCP architectures use VPC Peering and Shared VPC to connect networks securely. Private Services Access lets managed services like Cloud SQL operate with private IPs only — no public internet exposure.

### Key Concepts
- **VPC Peering** — Connects two VPC networks so they can communicate via private IPs. Non-transitive (A↔B and B↔C does NOT mean A↔C).
- **Shared VPC** — A centralized VPC owned by a host project that service projects can share. Used in multi-team organizations for centralized network governance.
- **Private Services Access** — Creates a VPC peering to Google's internal network, allowing managed services (Cloud SQL, Memorystore, etc.) to use private IPs.
- **Cloud SQL Private IP** — When `--no-assign-ip` is set, the Cloud SQL instance is only reachable from within the VPC.

---

## 🌉 Hands-on Tasks

### Task 1: Create Two VPC Networks

```bash
# Application VPC
gcloud compute networks create vpc-app --subnet-mode=custom
gcloud compute networks subnets create app-subnet \
    --network=vpc-app --region=us-east1 --range=10.10.0.0/24

# Database VPC
gcloud compute networks create vpc-db --subnet-mode=custom
gcloud compute networks subnets create db-subnet \
    --network=vpc-db --region=us-east1 --range=10.20.0.0/24
```

### Task 2: Set Up VPC Peering (Bidirectional)

```bash
# Peering from vpc-app to vpc-db
gcloud compute networks peerings create app-to-db \
    --network=vpc-app \
    --peer-network=vpc-db

# Peering from vpc-db to vpc-app (must be created in both directions)
gcloud compute networks peerings create db-to-app \
    --network=vpc-db \
    --peer-network=vpc-app
```

### Task 3: Set Up Private Services Access (for Cloud SQL)

```bash
# Allocate an IP range for Google-managed services
gcloud compute addresses create google-managed-services-range \
    --global \
    --purpose=VPC_PEERING \
    --prefix-length=16 \
    --network=vpc-app

# Create private connection to Google services
gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=google-managed-services-range \
    --network=vpc-app
```

### Task 4: Create Cloud SQL with Private IP Only

```bash
gcloud sql instances create ace-private-mysql \
    --database-version=MYSQL_8_0 \
    --tier=db-f1-micro \
    --region=us-east1 \
    --network=vpc-app \
    --no-assign-ip \
    --root-password="PrivateDBPass123" \
    --storage-auto-increase
```

### Task 5: Connect from a VM Inside the VPC

```bash
# Create VM in the app VPC
gcloud compute instances create app-vm \
    --zone=us-east1-b \
    --subnet=app-subnet \
    --machine-type=e2-micro \
    --image-family=debian-12 --image-project=debian-cloud

# Allow internal SSH
gcloud compute firewall-rules create allow-ssh-app \
    --network=vpc-app --allow=tcp:22

# Get the Cloud SQL private IP
PRIVATE_IP=$(gcloud sql instances describe ace-private-mysql \
    --format='value(ipAddresses[0].ipAddress)')
echo "Cloud SQL Private IP: $PRIVATE_IP"

# SSH into VM and connect to MySQL
gcloud compute ssh app-vm --zone=us-east1-b
# Inside the VM:
# sudo apt-get install -y default-mysql-client
# mysql -h $PRIVATE_IP -uroot -p
```

### Task 6: Test Cross-VPC Connectivity via Peering

```bash
# Create a VM in the db VPC
gcloud compute instances create db-vm \
    --zone=us-east1-b \
    --subnet=db-subnet \
    --machine-type=e2-micro \
    --image-family=debian-12 --image-project=debian-cloud

gcloud compute firewall-rules create allow-icmp-db \
    --network=vpc-db --allow=icmp --source-ranges=10.10.0.0/24

# From app-vm, ping db-vm's private IP (should work via peering)
DB_VM_IP=$(gcloud compute instances describe db-vm \
    --zone=us-east1-b --format='value(networkInterfaces[0].networkIP)')
gcloud compute ssh app-vm --zone=us-east1-b \
    --command="ping -c 3 $DB_VM_IP"
```

---

## ✅ Verification

```bash
# Verify VPC peering status
gcloud compute networks peerings list

# Verify Cloud SQL has NO public IP
gcloud sql instances describe ace-private-mysql \
    --format="yaml(ipAddresses)"

# Verify Private Services Access
gcloud compute addresses list --global \
    --filter="purpose=VPC_PEERING"
```

---

## 🧹 Cleanup

```bash
gcloud sql instances delete ace-private-mysql --quiet
gcloud compute instances delete app-vm db-vm --zone=us-east1-b --quiet
gcloud compute firewall-rules delete allow-ssh-app allow-icmp-db --quiet
gcloud compute networks peerings delete app-to-db --network=vpc-app --quiet
gcloud compute networks peerings delete db-to-app --network=vpc-db --quiet
gcloud compute networks subnets delete app-subnet db-subnet --region=us-east1 --quiet
gcloud compute networks delete vpc-app vpc-db --quiet
```

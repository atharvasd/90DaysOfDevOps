# Lab 13: Snapshots, Custom Images & Disk Management

**Exam Domain:** 4 — Ensuring successful operation (Backup, recovery, and operational management)

---

## Overview

Disk management is a core operational skill on GCP. Snapshots provide point-in-time backups, custom images create reusable golden images for VMs, and snapshot schedules automate regular backups.

### Key Concepts
- **Snapshot** — A point-in-time backup of a persistent disk. Snapshots are incremental (only changed blocks are stored). Can be used to create new disks in any region.
- **Custom Image** — A reusable VM image created from a disk. Used with Instance Templates and MIGs. Organize images into families.
- **Image Family** — A group of related images. When you reference a family, GCP automatically uses the latest non-deprecated image.
- **Snapshot Schedule** — A resource policy that automates periodic snapshots with retention policies.
- **Persistent Disk Types** — `pd-standard` (HDD), `pd-balanced` (SSD), `pd-ssd` (high-performance SSD), `pd-extreme` (highest IOPS).

---

## 📸 Hands-on Tasks

### Task 1: Create a Snapshot from a Running VM

```bash
# Create a VM first
gcloud compute instances create ace-snapshot-vm \
    --zone=us-east1-b \
    --machine-type=e2-micro \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-balanced

# Create a snapshot of the boot disk
gcloud compute snapshots create ace-boot-snapshot \
    --source-disk=ace-snapshot-vm \
    --source-disk-zone=us-east1-b \
    --labels=environment=dev,purpose=backup \
    --description="Snapshot of initial Debian 12 setup"
```

### Task 2: Create a New Disk from Snapshot

```bash
# Create a new disk from the snapshot (can be in a different zone!)
gcloud compute disks create ace-restored-disk \
    --source-snapshot=ace-boot-snapshot \
    --zone=us-east1-c \
    --type=pd-balanced

# Attach the restored disk to a new VM
gcloud compute instances create ace-restored-vm \
    --zone=us-east1-c \
    --machine-type=e2-micro \
    --disk=name=ace-restored-disk,boot=yes
```

### Task 3: Create a Custom Image

```bash
# Stop the VM first (required for consistent image)
gcloud compute instances stop ace-snapshot-vm --zone=us-east1-b

# Create image from the VM's boot disk
gcloud compute images create ace-golden-image \
    --source-disk=ace-snapshot-vm \
    --source-disk-zone=us-east1-b \
    --family=ace-custom-images \
    --description="Golden image with Debian 12 and base packages"

# Use the image family in a new VM (auto-picks latest)
gcloud compute instances create ace-from-golden \
    --zone=us-east1-b \
    --machine-type=e2-micro \
    --image-family=ace-custom-images
```

### Task 4: Create a Snapshot Schedule (Automated Backups)

```bash
# Create daily snapshot schedule with 7-day retention
gcloud compute resource-policies create snapshot-schedule ace-daily-backup \
    --region=us-east1 \
    --max-retention-days=7 \
    --daily-schedule \
    --start-time=02:00 \
    --on-source-disk-delete=apply-retention-policy

# Attach schedule to a disk
gcloud compute disks add-resource-policies ace-snapshot-vm \
    --zone=us-east1-b \
    --resource-policies=ace-daily-backup

# Verify attachment
gcloud compute disks describe ace-snapshot-vm \
    --zone=us-east1-b --format="yaml(resourcePolicies)"
```

### Task 5: Resize a Persistent Disk (Online)

```bash
# Start the VM back
gcloud compute instances start ace-snapshot-vm --zone=us-east1-b

# Resize disk online (no downtime required)
gcloud compute disks resize ace-snapshot-vm \
    --zone=us-east1-b \
    --size=20GB

# SSH in and extend the filesystem
gcloud compute ssh ace-snapshot-vm --zone=us-east1-b \
    --command="sudo resize2fs /dev/sda1"
```

---

## ✅ Verification

```bash
# List snapshots
gcloud compute snapshots list

# List custom images in family
gcloud compute images list --filter="family=ace-custom-images"

# List snapshot schedules
gcloud compute resource-policies list --filter="region=us-east1"

# Verify disk size
gcloud compute disks describe ace-snapshot-vm \
    --zone=us-east1-b --format="value(sizeGb)"
```

---

## 🧹 Cleanup

```bash
gcloud compute instances delete ace-snapshot-vm ace-from-golden --zone=us-east1-b --quiet
gcloud compute instances delete ace-restored-vm --zone=us-east1-c --quiet
gcloud compute disks delete ace-restored-disk --zone=us-east1-c --quiet
gcloud compute snapshots delete ace-boot-snapshot --quiet
gcloud compute images delete ace-golden-image --quiet
gcloud compute resource-policies delete ace-daily-backup --region=us-east1 --quiet
```

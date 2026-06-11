# Day 64 – Terraform State Management and Remote Backends (GCP)

---

## What is Terraform State?

The state file (`terraform.tfstate`) is Terraform's **memory**. It maps every resource in your `.tf` files to a real resource in the cloud. Without it, Terraform has no idea what exists — it would try to create everything from scratch.

```
Your .tf files → describe DESIRED state
terraform.tfstate → records ACTUAL state
terraform plan → compares the two and shows the diff
```

---

## Task 1: Inspecting State

### Resources tracked by Terraform

```bash
terraform state list
```

```
data.google_compute_image.debian_image
data.google_compute_zones.zones
google_compute_firewall.TerraWeek_Allow_HTTP
google_compute_instance.TerraWeek_Server
google_compute_network.TerraWeek_VPC
google_compute_route.TerraWeek_Route
google_compute_subnetwork.TerraWeek_Public_Subnet
google_storage_bucket.logs_bucket
```

**Total: 8 resources** (6 managed resources + 2 data sources)

### What does the state store for a Compute Engine instance?

Way more than what's in the `.tf` file. You define ~10 lines, but the state stores:
- Instance ID, self_link, and internal DNS
- Exact zone, machine type, CPU platform
- Boot disk details (image, size, type, device name)
- Network interface (internal IP, external IP, subnet)
- All labels (including provider-managed ones like `goog-terraform-provisioned`)
- Fingerprints for metadata, labels, and tags
- Creation timestamp
- Current status (RUNNING, STOPPED, etc.)

> This is why losing the state file is catastrophic — Terraform can't reconstruct all this information from your `.tf` files alone.

### What is the `serial` number?

The `serial` is a **version counter**. Every time you run `terraform apply`, it increments by 1. It's used by remote backends to detect **state conflicts** — if two people try to write state at the same time, the serial number mismatch prevents corruption.

---

## Task 2: Migrating to GCS Remote Backend

### Why remote state?

| Local State | Remote State (GCS) |
|---|---|
| Stored on your laptop | Stored in cloud storage |
| No backup | Versioned (can recover old state) |
| No locking | Built-in locking |
| Can't share with team | Shared across all team members |
| One `rm` and it's gone | Protected and durable |

### Backend configuration

Added to `providers.tf`:
```hcl
terraform {
  backend "gcs" {
    bucket = "terraweek-state-tws-bucket"
    prefix = "dev/terraform.tfstate"
  }
}
```

### GCS vs AWS (S3) for state storage

| Feature | GCS | S3 |
|---|---|---|
| State storage | GCS bucket | S3 bucket |
| State locking | **Built-in** ✅ | Requires separate DynamoDB table |
| Encryption at rest | Enabled by default | Must set `encrypt = true` |
| Versioning | `gsutil versioning set on` | `aws s3api put-bucket-versioning` |
| Config complexity | 2 fields (bucket, prefix) | 4 fields (bucket, key, region, dynamodb_table) |

### Migration steps
1. Created GCS bucket: `gcloud storage buckets create gs://terraweek-state-tws-bucket --location=asia-south1`
2. Enabled versioning: `gcloud storage buckets update gs://terraweek-state-tws-bucket --versioning`
3. Added backend block to `providers.tf`
4. Ran `terraform init` → answered **yes** to copy state
5. Verified with `terraform plan` → **No changes** (migration successful)

> **Gotcha:** When creating the bucket, it was initially created in the wrong GCP project because `gcloud` was configured to a different project than the Console. Fix: always verify your active project with `gcloud config get-value project` before running commands, or pass `--project=<id>` explicitly.

---

## Task 3: State Locking

### What is state locking?

When someone runs `terraform apply`, it **locks the state file**. No one else can read or write to it until the operation completes. This prevents:
- Two people applying conflicting changes simultaneously
- State file corruption from concurrent writes
- Race conditions in CI/CD pipelines

### How GCS locking works

GCS creates a **lock object** in the bucket alongside the state file. When the operation finishes, the lock is released. If a process crashes mid-apply, the lock becomes **stale** and must be manually removed:

```bash
terraform force-unlock <LOCK_ID>
```

> **Warning:** Only use `force-unlock` when you are 100% sure no other Terraform operation is running. Unlocking while another apply is in progress can corrupt your state.

---

## Task 4: Importing Existing Resources

### What is `terraform import`?

It brings a resource that **already exists in the cloud** under Terraform management — without recreating it.

### Steps performed

1. Manually created a GCS bucket `terraweek-import-test-atharvasd` in the Console
2. Added a resource block in `main.tf`:
```hcl
resource "google_storage_bucket" "imported" {
  name     = "terraweek-import-test-atharvasd"
  location = "ASIA-SOUTH1"
}
```
3. Imported it:
```bash
terraform import google_storage_bucket.imported <project-id>/terraweek-import-test-atharvasd
```
4. Ran `terraform plan` — it showed a change for the `encryption` block (the bucket had a default encryption config that wasn't in the `.tf` file)
5. Ran `terraform apply` to reconcile

### Import vs Creating from scratch

| `terraform import` | `terraform apply` (new) |
|---|---|
| Resource already exists in cloud | Terraform creates it from scratch |
| You write the `.tf` block first, then import | You write the `.tf` block, then apply |
| State is populated from cloud reality | State is populated from what Terraform creates |
| May need config adjustments to match reality | Config IS reality |
| No downtime — resource continues running | Resource is newly created |

---

## Task 5: State Surgery — `mv` and `rm`

### `terraform state mv` — Rename a resource

```bash
terraform state mv google_storage_bucket.imported google_storage_bucket.logs_bucket
```

This renames the resource **in state only**. You must also rename it in your `.tf` file to match, otherwise `terraform plan` will show a destroy + create.

**Real-world use cases:**
- Refactoring Terraform code (renaming resources for clarity)
- Moving a resource into a module
- Restructuring your `.tf` files without destroying infrastructure

### `terraform state rm` — Remove from state

```bash
terraform state rm google_storage_bucket.logs_bucket
```

This makes Terraform **forget** about the resource. The resource still exists in GCP — it just becomes "unmanaged."

After removal, `terraform plan` showed **1 to add** — because the `.tf` block still exists but Terraform thinks the resource doesn't.

**Real-world use cases:**
- Handing a resource off to another Terraform workspace or team
- Removing a resource from Terraform management without destroying it
- Fixing state corruption

### Re-importing after `state rm`

```bash
terraform import google_storage_bucket.logs_bucket <project-id>/terraweek-import-test-atharvasd
```

Brings the resource back under management → `terraform plan` shows **No changes** again.

---

## Task 6: State Drift

### What is drift?

Drift occurs when someone changes infrastructure **outside of Terraform** — through the Console, `gcloud` CLI, or another tool. Terraform's state becomes out of sync with reality.

### GCP Provider v5+ — Non-authoritative labels

> **Important:** The Google Terraform provider v5+ treats `labels` as **non-authoritative**. Adding a *new* label via the Console will NOT trigger drift detection. Terraform only manages labels defined in your `.tf` code. To trigger drift, you must change a label that Terraform explicitly manages (e.g., change `environment` from `dev` to `changed`).

### How to detect and fix drift

```bash
# Detect drift
terraform plan            # Shows diff between desired state and reality

# Option A: Reconcile (force reality to match your code)
terraform apply           # Reverts the manual change

# Option B: Accept (update your code to match reality)
# Edit your .tf files, then terraform plan shows "No changes"

# Refresh state without applying changes
terraform apply -refresh-only
```

### How teams prevent drift in production

1. **Restrict console access** — read-only for most team members
2. **All changes through CI/CD** — Terraform runs in a pipeline, not from laptops
3. **Drift detection schedules** — run `terraform plan` on a cron to catch unauthorized changes
4. **Policy enforcement** — tools like Sentinel or OPA that block non-Terraform changes

---

## Command Reference

| Command | Purpose |
|---|---|
| `terraform state list` | List all tracked resources |
| `terraform state show <resource>` | Show all attributes of a resource |
| `terraform state mv <old> <new>` | Rename a resource in state |
| `terraform state rm <resource>` | Remove a resource from state (keeps it in cloud) |
| `terraform import <resource> <id>` | Import an existing cloud resource into state |
| `terraform force-unlock <lock-id>` | Remove a stale state lock |
| `terraform apply -refresh-only` | Sync state with reality without applying changes |
| `terraform init -migrate-state` | Migrate state to a new backend |

---

## Summary

| Concept | Key Takeaway |
|---|---|
| **State file** | Terraform's memory — maps `.tf` to reality. Lose it and Terraform forgets everything. |
| **Remote backend** | Store state in GCS/S3 for durability, sharing, and locking |
| **State locking** | Prevents concurrent modifications — critical for teams |
| **Import** | Bring existing resources under Terraform management without recreating them |
| **State surgery** | `mv` to rename, `rm` to forget — neither affects the actual cloud resource |
| **Drift** | Manual changes outside Terraform. Detect with `plan`, fix with `apply` or update code |
| **Golden rule** | Once Terraform manages a resource, ALL changes go through Terraform |

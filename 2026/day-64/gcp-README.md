# Day 64 -- Terraform State Management and Remote Backends (GCP)

## Task
The state file is the single most important thing in Terraform. It is the source of truth -- the map between your `.tf` files and what actually exists in the cloud. Lose it and Terraform forgets everything. Corrupt it and your next apply could destroy production.

Today you learn to manage state like a professional -- remote backends, locking, importing existing resources, and handling drift.

---

## Expected Output
- Terraform state migrated from local to GCS remote backend with built-in locking
- An existing GCP resource imported into Terraform state
- State drift simulated and reconciled
- A markdown file: `day-64-state-management.md`

---

## Challenge Tasks

### Task 1: Inspect Your Current State
Use your Day 63 config. Apply it and then explore the state:

```bash
terraform show                                    # Full state in human-readable format
terraform state list                              # All resources tracked by Terraform
terraform state show google_compute_instance.main # Every attribute of the instance
terraform state show google_compute_network.main  # Every attribute of the VPC network
```

Answer:
1. How many resources does Terraform track?
2. What attributes does the state store for a Compute Engine instance? (hint: way more than what you defined)
3. Open `terraform.tfstate` in an editor -- find the `serial` number. What does it represent?

> **GCP vs AWS:** GCP state files look identical in structure to AWS ones -- Terraform's state format is provider-agnostic. The only difference is the resource type names (e.g., `google_compute_instance` vs `aws_instance`).

---

### Task 2: Set Up GCS Remote Backend
Storing state locally is dangerous -- one deleted file and you lose everything. Time to move it to GCS (Google Cloud Storage).

> **GCP vs AWS:** GCP's GCS backend has **built-in state locking** -- no separate DynamoDB table is needed. GCS handles locking natively using object versioning. This is simpler than AWS which requires S3 + DynamoDB separately.

1. First, create the GCS bucket for state storage:
```bash
# Create GCS bucket for state storage (bucket names must be globally unique)
gcloud storage buckets create gs://terraweek-state-tws-bucket --location=asia-south1

# Enable versioning (so you can recover previous state files)
gcloud storage buckets update gs://terraweek-state-tws-bucket --versioning

# Verify versioning is enabled
gcloud storage buckets describe gs://terraweek-state-tws-bucket --format="value(versioning)"
```

2. Add the backend block to your `providers.tf`:
```hcl
terraform {
  backend "gcs" {
    bucket = "terraweek-state-<yourname>"
    prefix = "dev/terraform.tfstate"
  }
}
```

> **Note:** GCS backend does not need a `region` field -- the bucket's region is set at creation time. There is also no `encrypt = true` field because GCS encrypts all data at rest by default.

3. Run:
```bash
terraform init
```
Terraform will ask: "Do you want to copy existing state to the new backend?" -- say yes.

4. Verify:
   - Check the GCS bucket: `gcloud storage ls gs://terraweek-state-<yourname>/dev/`
   - You should see `terraform.tfstate` inside it
   - Your local `terraform.tfstate` should now be empty or gone
   - Run `terraform plan` -- it should show no changes (state migrated correctly)

---

### Task 3: Test State Locking
State locking prevents two people from running `terraform apply` at the same time and corrupting the state.

1. Open **two terminals** in the same project directory
2. In Terminal 1, run:
```bash
terraform apply
```
3. While Terminal 1 is waiting for confirmation, in Terminal 2 run:
```bash
terraform plan
```
4. Terminal 2 should show a **lock error** with a Lock ID

**Document:** What is the error message? Why is locking critical for team environments?

5. After the test, if you get stuck with a stale lock:
```bash
terraform force-unlock <LOCK_ID>
```

> **GCP vs AWS:** GCS locking works by creating a lock object in the bucket. If a process crashes mid-apply, you may get a stale lock. `terraform force-unlock` removes it -- but only use it when you are absolutely sure no other operation is running.

---

### Task 4: Import an Existing Resource
Not everything starts with Terraform. Sometimes resources already exist in GCP and you need to bring them under Terraform management.

1. Manually create a GCS bucket in the GCP Console -- name it `terraweek-import-test-<yourname>`
2. Write a `resource "google_storage_bucket"` block in your config:
```hcl
resource "google_storage_bucket" "imported" {
  name     = "terraweek-import-test-<yourname>"
  location = "ASIA-SOUTH1"
}
```
3. Import it:
```bash
terraform import google_storage_bucket.imported <your-project-id>/terraweek-import-test-<yourname>
```
4. Run `terraform plan`:
   - If you see "No changes" -- the import was perfect
   - If you see changes -- your config does not match reality. Update your config to match, then plan again until you get "No changes"

5. Run `terraform state list` -- the imported bucket should now appear alongside your other resources

> **GCP vs AWS:** The import ID format for GCS buckets is `<project_id>/<bucket_name>`. For an AWS S3 bucket it would just be the bucket name. Always check the Terraform provider docs for the exact import ID format per resource type.

**Document:** What is the difference between `terraform import` and creating a resource from scratch?

---

### Task 5: State Surgery -- mv and rm
Sometimes you need to rename a resource or remove it from state without destroying it in GCP.

1. **Rename a resource in state:**
```bash
terraform state list                                          # Note the current resource names
terraform state mv google_storage_bucket.imported google_storage_bucket.logs_bucket
```
Update your `.tf` file to match the new name. Run `terraform plan` -- it should show no changes.

2. **Remove a resource from state (without destroying it):**
```bash
terraform state rm google_storage_bucket.logs_bucket
```
Run `terraform plan` -- Terraform no longer knows about the bucket, but it still exists in GCP.

3. **Re-import it** to bring it back:
```bash
terraform import google_storage_bucket.logs_bucket <your-project-id>/terraweek-import-test-<yourname>
```

**Document:** When would you use `state mv` in a real project? When would you use `state rm`?

---

### Task 6: Simulate and Fix State Drift
State drift happens when someone changes infrastructure outside of Terraform -- through the GCP Console, `gcloud` CLI, or another tool.

> **Important — GCP Provider v5+ Label Behavior:** The Google Terraform provider v5+ treats `labels` as **non-authoritative**. This means if you add a *new* label via the Console, Terraform will **not** detect it as drift — it only manages the labels defined in your `.tf` code and ignores any extras. To simulate drift, you must change a label or field that Terraform **explicitly manages**. This is different from AWS, where adding any tag triggers drift.

1. Apply your full config so everything is in sync
2. Go to the **GCP Console** and manually:
   - Go to Compute Engine → VM Instances
   - Edit your instance
   - Change an **existing label** that is defined in your `.tf` file (e.g., change `environment` from `dev` to `changed`)
   - Or change the instance **description** or **metadata**
   - Save the change
3. Run:
```bash
terraform plan
```
You should see a **diff** -- Terraform detects that reality no longer matches the desired state.

4. You have two choices:
   - **Option A:** Run `terraform apply` to force reality back to match your config (reconcile)
   - **Option B:** Update your `.tf` files to match the manual change (accept the drift)

5. Choose Option A -- apply and verify the value is restored in the GCP Console.

6. Run `terraform plan` again -- it should show "No changes." Drift resolved.

> **GCP vs AWS:** Drift detection works identically across providers for authoritative fields. The `terraform refresh` command (or `terraform apply -refresh-only`) updates state to match real infrastructure without making changes -- useful for syncing state before deciding what to do.

**Document:** How do teams prevent state drift in production? (hint: restrict console access, enforce all changes through CI/CD pipelines and Terraform)

---

## Hints
- GCS bucket names must be globally unique
- GCS backend handles locking natively -- no DynamoDB equivalent needed
- `terraform init -migrate-state` explicitly triggers state migration if needed
- `terraform apply -refresh-only` updates state to match real infrastructure without applying changes
- `gcloud storage buckets update gs://<bucket> --versioning` is critical -- it lets you recover a previous state file if something goes wrong
- `terraform force-unlock` should only be used when you are sure no other operation is running
- GCS import ID format: `<project_id>/<bucket_name>`
- Use `gcloud storage ls --all-versions gs://<bucket>/dev/` to see all versions of your state file

---

## Documentation
Create `day-64-state-management.md` with:
- Diagram: local state vs GCS remote state setup
- Screenshot of state file in GCS bucket
- Screenshot of the lock error from Task 3
- Steps you followed for `terraform import` and the result
- Explanation of state drift with your real example
- When to use: `state mv`, `state rm`, `import`, `force-unlock`, `refresh`

---

## Submission
1. Add `day-64-state-management.md` to `2026/day-64/`
2. Commit and push to your fork

---

## Learn in Public
Share on LinkedIn: "Mastered Terraform state today -- migrated to GCS remote backend with built-in locking, imported existing GCP resources, performed state surgery, and simulated drift. State management is the foundation of reliable infrastructure as code."

`#90DaysOfDevOps` `#TerraWeek` `#DevOpsKaJosh` `#TrainWithShubham`

Happy Learning!
**TrainWithShubham**

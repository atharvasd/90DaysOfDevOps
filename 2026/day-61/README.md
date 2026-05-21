# Day 61 -- Introduction to Terraform and Your First GCP Infrastructure

## Task
You have been deploying containers, writing CI/CD pipelines, and orchestrating workloads on Kubernetes. But who creates the servers, networks, and clusters underneath? Today you start your Infrastructure as Code journey with Terraform -- the tool that lets you define, provision, and manage cloud infrastructure by writing code.

By the end of today, you will have created real GCP resources using nothing but a `.tf` file and a terminal.

---

## Expected Output
- Terraform installed and working on your machine
- gcloud CLI configured with valid credentials
- A GCS bucket and Compute Engine VM created and destroyed via Terraform
- A markdown file: `day-61-terraform-intro.md`

---

## Challenge Tasks

### Task 1: Understand Infrastructure as Code
Before touching the terminal, research and write short notes on:

1. What is Infrastructure as Code (IaC)? Why does it matter in DevOps?
2. What problems does IaC solve compared to manually creating resources in the GCP console?
3. How is Terraform different from Google Cloud Deployment Manager, Ansible, and Pulumi?
4. What does it mean that Terraform is "declarative" and "cloud-agnostic"?

Write this in your own words -- not copy-pasted definitions.

---

### Task 2: Install Terraform and Configure GCP
1. Install Terraform:
```bash
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Linux (amd64)
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Windows
choco install terraform
```

2. Verify:
```bash
terraform -version
```

3. Install and configure the gcloud CLI:
```bash
# macOS
brew install --cask google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Authenticate and set your project
gcloud auth application-default login
gcloud config set project <your-project-id>
```

4. Verify GCP access:
```bash
gcloud auth list
gcloud projects describe <your-project-id>
```

You should see your active account and project details.

---

### Task 3: Your First Terraform Config -- Create a GCS Bucket
Create a project directory and write your first Terraform config:

```bash
mkdir terraform-basics && cd terraform-basics
```

Create a file called `main.tf` with:
1. A `terraform` block with `required_providers` specifying the `google` provider
2. A `provider "google"` block with your project ID and region
3. A `resource "google_storage_bucket"` that creates a bucket with a globally unique name

Run the Terraform lifecycle:
```bash
terraform init      # Download the Google provider
terraform plan      # Preview what will be created
terraform apply     # Create the bucket (type 'yes' to confirm)
```

Go to the GCP Cloud Storage console and verify your bucket exists.

**Document:** What did `terraform init` download? What does the `.terraform/` directory contain?

---

### Task 4: Add a Compute Engine VM
In the same `main.tf`, add:
1. A `resource "google_compute_instance"` using the `debian-cloud/debian-11` image
2. Set machine type to `e2-micro`
3. Add a label: `name = "terraweek-day1"`
4. Specify a `boot_disk` block with `initialize_params` pointing to the Debian image
5. Specify a `network_interface` block using the `default` network

Run:
```bash
terraform plan      # You should see 1 resource to add (bucket already exists)
terraform apply
```

Go to the GCP Compute Engine console and verify your instance is running with the correct label.

**Document:** How does Terraform know the GCS bucket already exists and only the Compute Engine VM needs to be created?

---

### Task 5: Understand the State File
Terraform tracks everything it creates in a state file. Time to inspect it.

1. Open `terraform.tfstate` in your editor -- read the JSON structure
2. Run these commands and document what each returns:
```bash
terraform show                                          # Human-readable view of current state
terraform state list                                    # List all resources Terraform manages
terraform state show google_storage_bucket.<name>       # Detailed view of a specific resource
terraform state show google_compute_instance.<name>
```

3. Answer these questions in your notes:
   - What information does the state file store about each resource?
   - Why should you never manually edit the state file?
   - Why should the state file not be committed to Git?

---

### Task 6: Modify, Plan, and Destroy
1. Change the Compute Engine instance label from `"terraweek-day1"` to `"terraweek-modified"` in your `main.tf`
2. Run `terraform plan` and read the output carefully:
   - What do the `~`, `+`, and `-` symbols mean?
   - Is this an in-place update or a destroy-and-recreate?
3. Apply the change
4. Verify the label changed in the GCP console
5. Finally, destroy everything:
```bash
terraform destroy
```
6. Verify in the GCP console -- both the GCS bucket and Compute Engine VM should be gone

---

## Hints
- GCS bucket names must be globally unique -- use something like `terraweek-<yourname>-2026`
- Enable the required APIs in your project before applying: `Compute Engine API` and `Cloud Storage API`
- `terraform fmt` auto-formats your `.tf` files -- run it before committing
- `terraform validate` checks for syntax errors without connecting to GCP
- The `.terraform/` directory contains downloaded provider plugins
- Add `*.tfstate`, `*.tfstate.backup`, and `.terraform/` to your `.gitignore`
- The `google` provider uses Application Default Credentials -- make sure `gcloud auth application-default login` has been run

---

## Documentation
Create `day-61-terraform-intro.md` with:
- IaC explanation in your own words (3-4 sentences)
- Screenshot of `terraform apply` creating your GCS bucket and Compute Engine VM
- Screenshot of the resources in the GCP console
- What each Terraform command does (init, plan, apply, destroy, show, state list)
- What the state file contains and why it matters

---

## Submission
1. Add `day-61-terraform-intro.md` to `2026/day-61/`
2. Commit and push to your fork

---

## Learn in Public
Share on LinkedIn: "Started the TerraWeek Challenge -- installed Terraform, created my first GCS bucket and Compute Engine VM using code, and destroyed it all with one command. Infrastructure as Code just clicked."

`#90DaysOfDevOps` `#TerraWeek` `#DevOpsKaJosh` `#TrainWithShubham`

Happy Learning!
**TrainWithShubham**

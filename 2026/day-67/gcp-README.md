# Day 67 -- TerraWeek Capstone: Multi-Environment Infrastructure with Workspaces and Modules (GCP)

## Task
Seven days of Terraform -- HCL, providers, resources, dependencies, variables, outputs, data sources, state management, remote backends, custom modules, registry modules, and a GKE cluster. Today you put it all together in one production-grade project.

Build a multi-environment GCP infrastructure using custom modules and Terraform workspaces. One codebase, three environments -- dev, staging, and prod. This is how infrastructure teams operate at scale.

---

## Expected Output
- A complete Terraform project with custom modules and proper file structure
- Three separate environments (dev, staging, prod) deployed using workspaces
- Each environment with its own VPC, firewall rules, and GCE instances with different sizing
- A markdown file: `day-67-terraweek-gcp-capstone.md`
- Everything destroyed cleanly after verification

---

## Challenge Tasks

### Task 1: Learn Terraform Workspaces
Before building the project, understand workspaces:

```bash
mkdir terraweek-gcp-capstone && cd terraweek-gcp-capstone
terraform init

# See current workspace
terraform workspace show                    # default

# Create new workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# List all workspaces
terraform workspace list

# Switch between them
terraform workspace select dev
terraform workspace select staging
terraform workspace select prod
```

Answer:
1. What does `terraform.workspace` return inside a config?
2. Where does each workspace store its state file locally?
3. How is this different from using separate directories per environment?

---

### Task 2: Set Up the Project Structure
Create this layout:

```
terraweek-gcp-capstone/
  main.tf                   # Root module -- calls child modules
  variables.tf              # Root variables
  outputs.tf                # Root outputs
  providers.tf              # Google provider and backend
  locals.tf                 # Local values using workspace
  dev.tfvars                # Dev environment values
  staging.tfvars            # Staging environment values
  prod.tfvars               # Prod environment values
  .gitignore                # Ignore state, .terraform, and credentials
  modules/
    vpc/
      main.tf
      variables.tf
      outputs.tf
    vpc-firewall/
      main.tf
      variables.tf
      outputs.tf
    gce-instance/
      main.tf
      variables.tf
      outputs.tf
```

Create the `.gitignore`:
```
.terraform/
*.tfstate
*.tfstate.backup
*.tfvars
.terraform.lock.hcl
```

---

### Task 3: Build the Custom Modules
Create three focused modules:

**Module 1: `modules/vpc/`**
- Input: `network_name`, `subnet_cidr`, `region`, `environment`, `project_name`
- Resources: VPC network (`google_compute_network`), subnet (`google_compute_subnetwork`) with `private_ip_google_access = true`
- Output: `network_name`, `subnet_name`

**Module 2: `modules/vpc-firewall/`**
- Input: `network_name`, `allowed_ports`, `environment`, `project_name`, `target_tags`
- Resources: Firewall rules (`google_compute_firewall`) with dynamic allow blocks
- Output: `firewall_name`

**Module 3: `modules/gce-instance/`**
- Input: `instance_name`, `machine_type`, `zone`, `network_name`, `subnet_name`, `target_tags`, `environment`, `project_name`
- Resources: Compute Engine instance with network interface, boot disk, and labels
- Output: `instance_id`, `external_ip`

Write and validate each module:
```bash
terraform validate
```

---

### Task 4: Wire It All Together with Workspace-Aware Config
In the root module, use `terraform.workspace` to drive environment-specific behavior.

**`locals.tf`:**
```hcl
locals {
  environment = terraform.workspace
  name_prefix = "${var.project_name}-${local.environment}"

  common_labels = {
    project     = var.project_name
    environment = local.environment
    managedby   = "terraform"
    workspace   = terraform.workspace
  }
}
```

**`variables.tf`:**
```hcl
variable "project_id" {
  type = string
}

variable "project_name" {
  type    = string
  default = "terraweek"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "subnet_cidr" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "ingress_ports" {
  type    = list(number)
  default = [22, 80]
}
```

**`main.tf`** -- call all three modules, passing workspace-aware names and variables.

**Environment-specific tfvars:**

`dev.tfvars`:
```hcl
subnet_cidr  = "10.0.0.0/24"
machine_type = "e2-micro"
ingress_ports = [22, 80]
```

`staging.tfvars`:
```hcl
subnet_cidr  = "10.1.0.0/24"
machine_type = "e2-small"
ingress_ports = [22, 80, 443]
```

`prod.tfvars`:
```hcl
subnet_cidr  = "10.2.0.0/24"
machine_type = "e2-medium"
ingress_ports = [80, 443] # Disable SSH port 22 in prod!
```

---

### Task 5: Deploy All Three Environments
Deploy each environment using its workspace and tfvars file:

**Dev:**
```bash
terraform workspace select dev
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

**Staging:**
```bash
terraform workspace select staging
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"
```

**Prod:**
```bash
terraform workspace select prod
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

After all three are deployed, verify:
```bash
# Check each workspace's resources
terraform workspace select dev && terraform output
terraform workspace select staging && terraform output
terraform workspace select prod && terraform output
```

Go to the GCP Console and verify:
- Three separate VPC networks with different CIDR ranges
- Three GCE VM instances with different machine sizes
- Correct labels on all resources (e.g., `environment = "prod"`)
- Firewall rules blocking port 22 in prod, but allowing it in dev/staging

---

### Task 6: Document Best Practices
Write down what you have learned this week as a Terraform GCP best practices guide:

1. **File structure** -- separate files for providers, variables, outputs, main, locals.
2. **State management** -- always use GCS remote backend, enable locking natively.
3. **Variables** -- never hardcode, use tfvars per environment, enforce lowercase for GCP labels.
4. **Modules** -- one concern per module, always define inputs/outputs, pin registry version.
5. **Workspaces** -- use for environment isolation, reference `terraform.workspace` in configs.
6. **Security** -- .gitignore for state and tfvars, restrict backend access, avoid committing service account keys.
7. **Cleanup** -- always `terraform destroy` non-production environments when not in use.

---

### Task 7: Destroy All Environments
Clean up all three environments in reverse order:

```bash
terraform workspace select prod
terraform destroy -var-file="prod.tfvars"

terraform workspace select staging
terraform destroy -var-file="staging.tfvars"

terraform workspace select dev
terraform destroy -var-file="dev.tfvars"
```

Delete the workspaces:
```bash
terraform workspace select default
terraform workspace delete dev
terraform workspace delete staging
terraform workspace delete prod
```

---

## Hints
- Each workspace has its own state file. Locally, these reside in `terraform.tfstate.d/<workspace>/terraform.tfstate`. In GCS, the prefix matches the workspace.
- GCP label keys and values MUST be lowercase and can only contain hyphens, underscores, or numbers.
- You cannot delete a workspace you are currently selected on. Switch to `default` first.

---

## Documentation
Create `day-67-terraweek-gcp-capstone.md` with:
- Your complete project structure (directory tree).
- All three custom module configs.
- Root `main.tf` showing workspace-aware module calls.
- Screenshot of all three environments running simultaneously in the GCP Console.
- Screenshot of `terraform output` from each workspace.
- Your Terraform best practices guide (Task 6).
- A table mapping each TerraWeek day to the GCP concepts learned.

---

## Submission
1. Add `day-67-terraweek-gcp-capstone.md` to `2026/day-67/`
2. Commit and push to your fork.

---

## Learn in Public
Share on LinkedIn: "Completed the TerraWeek Challenge on GCP! Developed a multi-environment infrastructure codebase using custom VPC, firewall, and GCE modules. Used Terraform Workspaces to deploy completely isolated dev, staging, and prod environments in GCP. Clean, modular, and automated."

`#90DaysOfDevOps` `#TerraWeek` `#DevOpsKaJosh` `#TrainWithShubham`

Happy Learning!
**TrainWithShubham**

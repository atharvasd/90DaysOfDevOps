# Day 63 -- Variables, Outputs, Data Sources and Expressions

## Task
Your Day 62 config works, but it is full of hardcoded values -- region, CIDR blocks, image names, machine types, tags. Change the region and everything breaks. Today you make your Terraform configs dynamic, reusable, and environment-aware.

This is the difference between a config that works once and a config you can use across projects.

---

## Expected Output
- A fully parameterized Terraform config with no hardcoded values
- Separate `.tfvars` files for different environments
- Outputs printed after every apply
- A markdown file: `day-63-variables-outputs.md`

---

## Challenge Tasks

### Task 1: Extract Variables
Take your Day 62 infrastructure config and refactor it:

1. Create a `variables.tf` file with input variables for:
   - `region` (string, default: your preferred region)
   - `zone` (string, default: your preferred zone e.g. `"asia-south1-a"`)
   - `project_id` (string, no default -- force the user to provide it)
   - `subnet_cidr` (string, default: `"10.0.1.0/24"`)
   - `machine_type` (string, default: `"e2-micro"`)
   - `project_name` (string, no default -- force the user to provide it)
   - `environment` (string, default: `"dev"`)
   - `allowed_ports` (list of numbers, default: `[22, 80, 443]`)
   - `extra_labels` (map of strings, default: `{}`)

   > **GCP vs AWS:** GCP networks do not have a CIDR block -- only subnets do. So there is no `vpc_cidr` equivalent. Also note GCP uses `labels` for resource metadata (like AWS tags), while `tags` in GCP are network tags used for firewall targeting.

2. Replace every hardcoded value in `main.tf` with `var.<name>` references
3. Run `terraform plan` -- it should prompt you for `project_id` and `project_name` since they have no defaults

**Document:** What are the five variable types in Terraform? (`string`, `number`, `bool`, `list`, `map`)

---

### Task 2: Variable Files and Precedence
1. Create `terraform.tfvars`:
```hcl
project_id   = "your-gcp-project-id"
project_name = "terraweek"
environment  = "dev"
machine_type = "e2-micro"
```

2. Create `prod.tfvars`:
```hcl
project_id   = "your-gcp-project-id"
project_name = "terraweek"
environment  = "prod"
machine_type = "e2-small"
subnet_cidr  = "10.1.1.0/24"
```

3. Apply with the default file:
```bash
terraform plan                              # Uses terraform.tfvars automatically
```

4. Apply with the prod file:
```bash
terraform plan -var-file="prod.tfvars"      # Uses prod.tfvars
```

5. Override with CLI:
```bash
terraform plan -var="machine_type=e2-medium"  # CLI overrides everything
```

6. Set an environment variable:
```bash
export TF_VAR_environment="staging"
terraform plan                              # env var overrides default but not tfvars
```

**Document:** Write the variable precedence order from lowest to highest priority.

---

### Task 3: Add Outputs
Create an `outputs.tf` file with outputs for:

1. `network_id` -- the VPC network ID
2. `subnetwork_id` -- the public subnetwork ID
3. `instance_id` -- the Compute Engine instance ID
4. `instance_public_ip` -- the public IP of the instance
5. `instance_self_link` -- the fully-qualified GCP resource URL of the instance
6. `firewall_rule_id` -- the firewall rule ID

```hcl
output "instance_public_ip" {
  value = google_compute_instance.main.network_interface[0].access_config[0].nat_ip
}

output "instance_self_link" {
  value = google_compute_instance.main.self_link
}
```

Apply your config and verify the outputs are printed at the end:
```bash
terraform apply

# After apply, you can also run:
terraform output                          # Show all outputs
terraform output instance_public_ip       # Show a specific output
terraform output -json                    # JSON format for scripting
```

> **GCP vs AWS:** GCP instances do not get a public DNS name by default (unlike AWS EC2 which gets a `ec2-x-x-x-x.compute.amazonaws.com` hostname). Use `self_link` as the stable resource identifier instead.

**Verify:** Does `terraform output instance_public_ip` return the correct IP?

---

### Task 4: Use Data Sources
Stop hardcoding the image name. Use a data source to fetch it dynamically.

1. Add a `data "google_compute_image"` block that:
   - Fetches the latest Debian 11 image
   - Uses `family = "debian-11"` and `project = "debian-cloud"`

```hcl
data "google_compute_image" "debian" {
  family  = "debian-11"
  project = "debian-cloud"
}
```

2. Replace the hardcoded image in your `google_compute_instance` with `data.google_compute_image.debian.self_link`

3. Add a `data "google_compute_zones"` block to fetch available zones in your region:
```hcl
data "google_compute_zones" "available" {
  region = var.region
}
```

4. Use the first available zone in your instance: `data.google_compute_zones.available.names[0]`

Apply and verify -- your config now works in any region without changing the image name.

**Document:** What is the difference between a `resource` and a `data` source?

---

### Task 5: Use Locals for Dynamic Values
1. Add a `locals` block:
```hcl
locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  common_labels = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}
```

> **GCP vs AWS:** GCP label keys and values must be lowercase and can only contain letters, numbers, hyphens, and underscores. AWS tag keys have no such restriction.

2. Replace all hardcoded names with `local.name_prefix`:
   - Network: `"${local.name_prefix}-vpc"`
   - Subnet: `"${local.name_prefix}-subnet"`
   - Instance: `"${local.name_prefix}-server"`

3. Merge common labels with resource-specific labels:
```hcl
labels = merge(local.common_labels, {
  name = "${local.name_prefix}-server"
})
```

Apply and check the labels in the GCP console -- every resource should have consistent labeling.

---

### Task 6: Built-in Functions and Conditional Expressions
Practice these in `terraform console`:
```bash
terraform console
```

1. **String functions:**
   - `upper("terraweek")` -> `"TERRAWEEK"`
   - `join("-", ["terra", "week", "2026"])` -> `"terra-week-2026"`
   - `format("projects/%s/zones/%s/instances/%s", "my-project", "asia-south1-a", "my-vm")`

2. **Collection functions:**
   - `length(["a", "b", "c"])` -> `3`
   - `lookup({dev = "e2-micro", prod = "e2-small"}, "dev")` -> `"e2-micro"`
   - `toset(["a", "b", "a"])` -> removes duplicates

3. **Networking function:**
   - `cidrsubnet("10.0.0.0/16", 8, 1)` -> `"10.0.1.0/24"`

4. **Conditional expression** -- add this to your config:
```hcl
machine_type = var.environment == "prod" ? "e2-small" : "e2-micro"
```

Apply with `environment = "prod"` and verify the machine type changes.

**Document:** Pick five functions you find most useful and explain what each does.

---

## Hints
- `terraform.tfvars` is loaded automatically. Any other `.tfvars` file needs `-var-file`
- Variable precedence (low to high): default -> `terraform.tfvars` -> `*.auto.tfvars` -> `-var-file` -> `-var` flag -> `TF_VAR_*` env vars
- `terraform console` is an interactive REPL for testing expressions and functions
- Data sources are read-only -- they fetch information, they don't create resources
- `merge()` combines two maps -- great for labels
- `terraform output -json` is useful when piping output into other scripts
- GCP label values must be lowercase -- use `lower()` to enforce this: `lower(var.environment)`
- `google_compute_instance.main.network_interface[0].access_config[0].nat_ip` is the path to the public IP

---

## Documentation
Create `day-63-variables-outputs.md` with:
- Your `variables.tf` with all variable types
- Both `.tfvars` files (dev and prod)
- Screenshot of outputs after `terraform apply`
- Explanation of variable precedence with examples
- Five built-in functions you found most useful
- The difference between `variable`, `local`, `output`, and `data`

---

## Submission
1. Add `day-63-variables-outputs.md` to `2026/day-63/`
2. Commit and push to your fork

---

## Learn in Public
Share on LinkedIn: "Made my Terraform configs fully dynamic today -- variables for every environment, data sources for image lookups, locals for consistent labeling, and conditional expressions for environment-specific sizing. Zero hardcoded values."

`#90DaysOfDevOps` `#TerraWeek` `#DevOpsKaJosh` `#TrainWithShubham`

Happy Learning!
**TrainWithShubham**

# Day 65 -- Terraform Modules: Build Reusable Infrastructure (GCP)

## Task
You have been writing everything in one big `main.tf` file. That works for learning, but in real teams you manage dozens of environments with hundreds of resources. Copy-pasting configs across projects is a recipe for disaster.

Today you learn Terraform modules -- the way to package, reuse, and share infrastructure code. Think of modules as functions in programming: write once, call many times. You will build custom modules for Google Compute Engine (GCE) instances and VPC firewall rules, and use the official Google VPC module from the Terraform Registry.

---

## Expected Output
- A custom GCE instance module you built from scratch
- A custom VPC firewall module wired into the GCE module
- A VPC created using the official Google Cloud VPC registry module
- A markdown file: `day-65-gcp-modules.md`

---

## Challenge Tasks

### Task 1: Understand Module Structure
A Terraform module is just a directory with `.tf` files. Create this structure:

```
terraform-gcp-modules/
  main.tf                    # Root module -- calls child modules
  variables.tf               # Root variables
  outputs.tf                 # Root outputs
  providers.tf               # Provider config
  modules/
    gce-instance/
      main.tf                # GCE resource definition
      variables.tf           # Module inputs
      outputs.tf             # Module outputs
    vpc-firewall/
      main.tf                # Firewall rule resource definition
      variables.tf           # Module inputs
      outputs.tf             # Module outputs
```

Create all the directories and empty files. This is the standard layout every Terraform project follows.

**Document:** What is the difference between a "root module" and a "child module"?

---

### Task 2: Build a Custom GCE Module
Create `modules/gce-instance/`:

1. **`variables.tf`** -- define inputs:
   - `instance_name` (string)
   - `machine_type` (string, default: `"e2-micro"`)
   - `zone` (string)
   - `network` (string)
   - `subnetwork` (string)
   - `image` (string, default: `"debian-cloud/debian-12"`)
   - `labels` (map of strings, default: `{}`)
   - `target_tags` (list of strings, default: `[]`)

2. **`main.tf`** -- define the resource:
   - `google_compute_instance` using all the variables.
   - Define a `boot_disk` block referencing the image variable.
   - Define a `network_interface` referencing the network/subnetwork variables and including an empty `access_config` block (to assign a public IP).
   - Apply `tags` using the `target_tags` variable (GCP uses tags for routing/firewalls).

3. **`outputs.tf`** -- expose:
   - `instance_id`
   - `external_ip` (access_config[0].nat_ip)
   - `self_link`

Do NOT apply yet -- just write the module.

---

### Task 3: Build a Custom Firewall Module
GCP firewall rules are global resources attached to a VPC network. They are applied to instances using **network tags**.

Create `modules/vpc-firewall/`:

1. **`variables.tf`** -- define inputs:
   - `firewall_name` (string)
   - `network_name` (string)
   - `allowed_ports` (list of numbers, default: `[22, 80]`)
   - `target_tags` (list of strings, default: `[]`)

2. **`main.tf`** -- define the resource:
   - `google_compute_firewall` linked to `network_name`.
   - Use a `dynamic "allow"` block to handle the protocols and ports.
   - Set `target_tags` so the firewall rules only apply to GCE instances with matching tags.

```hcl
resource "google_compute_firewall" "custom" {
  name    = var.firewall_name
  network = var.network_name

  dynamic "allow" {
    for_each = var.allowed_ports
    content {
      protocol = "tcp"
      ports    = [allow.value]
    }
  }

  target_tags = var.target_tags
}
```

3. **`outputs.tf`** -- expose:
   - `firewall_id`

---

### Task 4: Call Your Modules from Root
In the root `main.tf`, wire everything together:

1. Create a VPC network and subnet directly (or reuse your Day 62 config).
2. Call the custom firewall module:
```hcl
module "web_firewall" {
  source        = "./modules/vpc-firewall"
  firewall_name = "terraweek-web-firewall"
  network_name  = google_compute_network.custom_network.name
  allowed_ports = [22, 80, 443]
  target_tags   = ["web-server"]
}
```

3. Call the GCE module -- deploy **two instances** (web and API) with different names using the same module:
```hcl
module "web_server" {
  source        = "./modules/gce-instance"
  instance_name = "terraweek-web"
  machine_type  = "e2-micro"
  zone          = "us-central1-a"
  network       = google_compute_network.custom_network.name
  subnetwork    = google_compute_subnetwork.custom_subnet.name
  target_tags   = ["web-server"]
  labels        = { environment = "dev", role = "web" }
}

module "api_server" {
  source        = "./modules/gce-instance"
  instance_name = "terraweek-api"
  machine_type  = "e2-micro"
  zone          = "us-central1-a"
  network       = google_compute_network.custom_network.name
  subnetwork    = google_compute_subnetwork.custom_subnet.name
  target_tags   = ["web-server"] # Will reuse same firewall rules
  labels        = { environment = "dev", role = "api" }
}
```

4. Add root outputs that reference module outputs:
```hcl
output "web_server_ip" {
  value = module.web_server.external_ip
}

output "api_server_ip" {
  value = module.api_server.external_ip
}
```

5. Apply:
```bash
terraform init    # Downloads/links the local modules
terraform plan    # Should show all resources from both module calls
terraform apply
```

**Verify:** Two GCE instances running, sharing the same network tag, accessible via the specified ports. Check the GCP Console.

---

### Task 5: Use a Public Registry Module
Instead of building your own VPC from scratch, use the official Google Project network module from the Terraform Registry.

1. Replace your hand-written VPC resources with:
```hcl
module "vpc" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 9.0"
  project_id   = var.project_id
  network_name = "terraweek-registry-vpc"

  subnets = [
    {
      subnet_name   = "subnet-01"
      subnet_ip     = "10.10.10.0/24"
      subnet_region = "us-central1"
    }
  ]
}
```

2. Update your GCE and Firewall module calls to reference `module.vpc.network_name` and `module.vpc.subnets_names[0]` (or use outputs from the registry module).

3. Run:
```bash
terraform init     # Downloads the registry module
terraform plan
terraform apply
```

4. Compare: how many resources did the VPC module create vs your hand-written VPC?

**Document:** Where does Terraform download registry modules to? Check `.terraform/modules/`.

---

### Task 6: Module Versioning and Best Practices
1. Pin your registry module version explicitly:
   - `version = "9.1.0"` -- exact version
   - `version = "~> 9.0"` -- any 9.x version
2. Run `terraform init -upgrade` to check for newer versions.
3. Check the state to see how modules appear:
```bash
terraform state list
```
4. Destroy everything:
```bash
terraform destroy
```

**Document:** Write down five module best practices:
- Always pin versions for registry modules.
- Keep modules focused on one concern.
- Use variables for configuration, avoid hardcoding.
- Always define outputs so root config can query resource outputs.
- Write a simple README.md inside each custom module.

---

## Hints
- `terraform init` must be re-run after adding a new module source or updating a version.
- Module outputs are accessed as `module.<name>.<output>`.
- GCP label values must be lowercase and use hyphens/underscores only.
- In GCP, VM instances get their public IPs via the `access_config {}` nested block inside `network_interface`. Leaving it empty assigns an ephemeral external IP.
- Reference: [Terraform Registry - Google Network Module](https://registry.terraform.io/modules/terraform-google-modules/network/google/)

---

## Documentation
Create `day-65-gcp-modules.md` with:
- Your custom module structure (directory tree).
- The `variables.tf`, `main.tf`, and `outputs.tf` for your GCE module.
- Root `main.tf` showing how you call both custom and registry modules.
- Screenshot of both VM instances running in GCE from the same module.
- Comparison: hand-written VPC vs registry VPC module.
- Five module best practices in your own words.

---

## Submission
1. Add `day-65-gcp-modules.md` to `2026/day-65/`
2. Commit and push to your fork.

---

## Learn in Public
Share on LinkedIn: "Built my first custom Terraform modules on GCP today -- GCE instances and dynamic firewall rule modules called multiple times. Then replaced manual VPC code with the official Google Cloud Registry network module. Reusable infrastructure as code is a game changer."

`#90DaysOfDevOps` `#TerraWeek` `#DevOpsKaJosh` `#TrainWithShubham`

Happy Learning!
**TrainWithShubham**

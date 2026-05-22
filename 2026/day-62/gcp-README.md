# Day 62 -- Providers, Resources and Dependencies

## Task
Yesterday you created standalone resources. But real infrastructure is connected -- a server lives inside a subnet, a subnet lives inside a VPC, a firewall rule controls what traffic gets in. Today you build a complete networking stack on GCP and learn how Terraform figures out what to create first.

Understanding dependencies is what separates a Terraform beginner from someone who can build production infrastructure.

---

## Expected Output
- A VPC network with subnet, internet route, firewall rules, and a Compute Engine instance -- all created via Terraform
- A dependency graph visualized with `terraform graph`
- A markdown file: `day-62-providers-resources.md`

---

## Challenge Tasks

### Task 1: Explore the Google Provider
1. Create a new project directory: `terraform-gcp-infra`
2. Write a `providers.tf` file:
   - Define the `terraform` block with `required_providers` pinning the Google provider to version `~> 5.0`
   - Define the `provider "google"` block with your project ID and region
3. Run `terraform init` and check the output -- what version was installed?
4. Read the provider lock file `.terraform.lock.hcl` -- what does it do?

**Document:** What does `~> 5.0` mean? How is it different from `>= 5.0` and `= 5.0.0`?

---

### Task 2: Build a VPC Network from Scratch
Create a `main.tf` and define these resources one by one:

1. `google_compute_network` -- set `auto_create_subnetworks = false` (custom mode), tag it `"TerraWeek-VPC"`
2. `google_compute_subnetwork` -- IP range `10.0.1.0/24`, reference the network from step 1, tag it `"TerraWeek-Public-Subnet"`
3. `google_compute_route` -- add a default internet route (`dest_range = "0.0.0.0/0"`) with `next_hop_gateway = "default-internet-gateway"`, reference the network
4. `google_compute_firewall` (SSH) -- allow TCP port 22 from `0.0.0.0/0` on the VPC network

Run `terraform plan` -- you should see 4 resources to create.

> **GCP vs AWS:** AWS requires 5 resources for equivalent connectivity (VPC + subnet + internet gateway + route table + route table association). GCP combines the internet gateway and route table association concepts -- the internet gateway is built-in, and routes apply directly to the network without an association resource.

**Verify:** Apply and check the GCP VPC Networks console. Can you see the network, subnet, route, and firewall rule?

---

### Task 3: Understand Implicit Dependencies
Look at your `main.tf` carefully:

1. The subnet references `google_compute_network.main.id` -- this is an implicit dependency
2. The route references the network ID -- another implicit dependency
3. The firewall rule references the network

Answer these questions:
- How does Terraform know to create the VPC network before the subnet?
- What would happen if you tried to create the subnet before the network existed?
- Find all implicit dependencies in your config and list them

---

### Task 4: Add Firewall Rules and a Compute Engine Instance
Add to your config:

1. A second `google_compute_firewall` rule on the VPC network:
   - Allow TCP port 80 (HTTP) from `0.0.0.0/0`
   - Add a `target_tags = ["web"]` to scope it to tagged instances only
   - Tag: `"TerraWeek-Allow-HTTP"`

2. `google_compute_instance` in the subnet:
   - Use image `debian-cloud/debian-11`
   - Machine type: `e2-micro`
   - Zone: your preferred zone (e.g. `asia-south1-a`)
   - Reference the network and subnetwork from Task 2
   - Add `access_config {}` inside `network_interface` -- this assigns an ephemeral public IP
   - Add `tags = ["web"]` so the HTTP firewall rule applies
   - Tag: `"TerraWeek-Server"`

```hcl
resource "google_compute_instance" "main" {
  name         = "terraweek-server"
  machine_type = "e2-micro"
  zone         = "asia-south1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.main.id
    subnetwork = google_compute_subnetwork.public.id
    access_config {}  # assigns ephemeral public IP
  }

  tags = ["web"]
}
```

Apply and verify -- your Compute Engine instance should have a public IP visible in the console.

> **GCP vs AWS:** AWS security groups attach to the instance. GCP firewall rules attach to the **network** and are scoped to instances using **network tags** or service accounts. The `access_config {}` block is GCP's equivalent of `associate_public_ip_address = true`.

---

### Task 5: Explicit Dependencies with depends_on
Sometimes Terraform cannot detect a dependency automatically.

1. Add a `google_storage_bucket` resource for application logs:
```hcl
resource "google_storage_bucket" "logs" {
  name          = "terraweek-logs-<yourname>-2026"
  location      = "ASIA-SOUTH1"
  force_destroy = true
  depends_on    = [google_compute_instance.main]
}
```
2. Even though there is no direct reference between the bucket and the instance, `depends_on` forces the bucket to be created only after the instance is up
3. Run `terraform plan` and observe the creation order

Now visualize the entire dependency tree:
```bash
terraform graph | dot -Tpng > graph.png
```
If you don't have `dot` (Graphviz) installed, use:
```bash
terraform graph
```
and paste the output into an online Graphviz viewer.

**Document:** When would you use `depends_on` in real projects? Give two examples.

---

### Task 6: Lifecycle Rules and Destroy
1. Add a `lifecycle` block to your Compute Engine instance:
```hcl
lifecycle {
  create_before_destroy = true
}
```
2. Change the boot disk image to `debian-cloud/debian-12` and run `terraform plan` -- observe that Terraform plans to create the new instance before destroying the old one

3. Destroy everything:
```bash
terraform destroy
```
4. Watch the destroy order -- Terraform destroys in reverse dependency order. Verify in the GCP console that the instance, firewall rules, route, subnet, and VPC network are all gone.

**Document:** What are the three lifecycle arguments (`create_before_destroy`, `prevent_destroy`, `ignore_changes`) and when would you use each?

---

## Hints
- `google_compute_network.main.id` syntax: `<resource_type>.<resource_name>.<attribute>`
- Use `terraform fmt` to keep your HCL clean
- CIDR `10.0.0.0/16` gives you 65,536 IPs, `10.0.1.0/24` gives you 256
- GCP VPCs are **global** -- one VPC spans all regions, unlike AWS where VPCs are regional
- GCP firewall rules use `target_tags` to scope rules to specific instances -- no per-instance security group attachment needed
- `access_config {}` with no arguments gives an ephemeral (dynamic) public IP; use `nat_ip` inside it to assign a static IP
- GCS bucket names must be globally unique -- use `terraweek-<yourname>-2026`
- `terraform graph` outputs DOT format -- paste it into webgraphviz.com if you don't have Graphviz
- Enable the required APIs before applying: `Compute Engine API` and `Cloud Storage API`
- Always destroy resources when done to avoid GCP charges

---

## Documentation
Create `day-62-providers-resources.md` with:
- Your full `main.tf` with comments explaining each resource
- Screenshot of `terraform apply` output
- Screenshot of the VPC network and its resources in the GCP console
- The dependency graph (image or text)
- Explanation of implicit vs explicit dependencies in your own words
- Key differences you noticed between GCP and AWS networking in Terraform

---

## Submission
1. Add `day-62-providers-resources.md` to `2026/day-62/`
2. Commit and push to your fork

---

## Learn in Public
Share on LinkedIn: "Built a complete GCP networking stack with Terraform today -- VPC network, subnets, internet routes, firewall rules, and a Compute Engine instance. All connected through dependency graphs. Terraform decides the order, you define the desired state."

`#90DaysOfDevOps` `#TerraWeek` `#DevOpsKaJosh` `#TrainWithShubham`

Happy Learning!
**TrainWithShubham**

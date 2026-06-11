# Lab 01: Dynamic Inventories (AWS/GCP)

**Topic:** Advanced Ansible

---

## Overview

In the core curriculum, you used a static `inventory.ini` file containing hardcoded IP addresses. In a cloud environment with Autoscaling Groups or dynamic IP assignments, keeping a static inventory up to date is impossible.

Ansible solves this with **Dynamic Inventories**. These are plugins that query cloud provider APIs (AWS, GCP, Azure) in real-time to build the inventory on the fly.

---

## 🛠️ Hands-on Tasks

### Task 1: Setup AWS Dynamic Inventory

*Note: This task assumes you have AWS CLI configured with valid credentials.*

1. **Install the AWS collection and requirements:**
```bash
ansible-galaxy collection install amazon.aws
pip install boto3 botocore
```

2. **Create the inventory configuration file (`aws_ec2.yml`):**
```yaml
# aws_ec2.yml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
  - us-west-2
filters:
  # Only include instances with the 'Environment' tag set to 'Production'
  tag:Environment: Production
  # Only include running instances
  instance-state-name: running
keyed_groups:
  # Create groups based on the 'Role' tag (e.g., tag_Role_webserver)
  - key: tags.Role
    prefix: role
  # Create groups based on the OS
  - key: platform_details
    prefix: os
hostnames:
  - private-ip-address
```

### Task 2: Test the Inventory

Instead of running a playbook immediately, you can preview the dynamic inventory using `ansible-inventory`.

```bash
# View the dynamically generated JSON inventory
ansible-inventory -i aws_ec2.yml --graph

# Test a ping command to a dynamically generated group
ansible role_webserver -i aws_ec2.yml -m ping
```

### Task 3: Setup GCP Dynamic Inventory (Bonus)

If you are using Google Cloud, the process is very similar.

1. **Install the GCP collection:**
```bash
ansible-galaxy collection install google.cloud
pip install requests google-auth
```

2. **Create `gcp_compute.yml`:**
```yaml
# gcp_compute.yml
plugin: google.cloud.gcp_compute
projects:
  - my-gcp-project-id
zones:
  - us-central1-a
filters:
  - status = RUNNING
auth_kind: application
groups:
  webservers: "'web' in name"
```

3. **Test:**
```bash
ansible-inventory -i gcp_compute.yml --graph
```

---

## ✅ Best Practices
- **Use Plugins, Not Scripts:** Older tutorials mention "inventory scripts" (e.g., `ec2.py`). These are deprecated. Always use modern Inventory Plugins (ending in `.yml`).
- **Tagging is Everything:** Dynamic inventories rely heavily on Cloud tags. Enforce strict tagging policies (e.g., via Terraform) so Ansible can accurately group resources.

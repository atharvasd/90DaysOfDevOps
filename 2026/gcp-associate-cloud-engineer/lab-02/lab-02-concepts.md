# Lab 02 Concepts: Custom VPC Networks and Compute Engine

## 1. Virtual Private Cloud (VPC)
A VPC in Google Cloud is a virtual version of a traditional physical data center network. It provides connectivity for your Compute Engine VM instances, Kubernetes Engine clusters, App Engine flexible environment instances, and other resources in your project.

### Global vs. Regional
- **Global VPCs:** Unlike AWS (where a VPC is bound to a specific region), a GCP VPC is **Global**. A single VPC can span multiple regions around the world.
- **Regional Subnets:** While the VPC itself is global, the **Subnets** inside it are **Regional**. For example, you can have one subnet in `us-east1` and another in `europe-west1` but they are both part of the same global VPC.

### Auto Mode vs. Custom Mode
- **Auto Mode VPC:** When created, GCP automatically provisions one subnet in *every single region* with a pre-defined IP range. This is great for quick testing, but terrible for production because it gives you less control over your IP address spacing and makes peering difficult.
- **Custom Mode VPC:** No subnets are created automatically. You manually define exactly which subnets you want, in which regions, and what their specific IP address ranges are. This is the **best practice** for production.

## 2. Firewall Rules
By default, GCP blocks all incoming traffic to your VMs and allows all outgoing traffic. To allow incoming traffic, you must create Firewall Rules.

- **Direction:** `Ingress` (incoming) or `Egress` (outgoing).
- **Targeting:** Instead of applying rules only to specific IP addresses, GCP allows you to apply rules using **Network Tags**. For example, you can tag 10 VMs as `web-server` and create a single firewall rule that says "allow port 80 to any VM tagged `web-server`".
- **Priority:** Rules are evaluated based on priority numbers (0 to 65535, with 0 being the highest priority).

## 3. Compute Engine Instances
Compute Engine is GCP's Infrastructure-as-a-Service (IaaS) offering that lets you run Virtual Machines.

### Key Components
- **Machine Type:** Determines the CPU and RAM (e.g., `e2-micro`, `n2-standard-4`).
- **Image:** The operating system that the VM runs (e.g., Debian, Ubuntu, Windows Server).
- **Startup Scripts:** A bash script that you provide to the VM. The very first time the VM boots up, it automatically runs this script. This is incredibly useful for automatically installing software (like an Apache web server) without human intervention.

# Lab 01 Concepts: IAM, Projects, and gcloud CLI Configuration

## 1. Google Cloud Projects
A **Project** is the fundamental organizing entity in Google Cloud. Think of it as a logical container.
- **Why it's needed:** Every resource you create (like virtual machines, databases, storage buckets) must belong to a project.
- **Billing:** Projects are linked to a single Billing Account. When resources are consumed, the project tallies the cost and bills the linked account.
- **Hierarchy:** Projects often sit inside "Folders", which sit inside an "Organization" (e.g., `Company Org > Finance Folder > Payroll Project`).

## 2. The `gcloud` CLI and Configurations
The `gcloud` command-line tool allows you to manage GCP from your terminal. 
- **Configurations:** A configuration is a local profile stored on your computer that remembers your default settings, primarily:
  - Which Google Account is active.
  - Which Project is currently targeted.
  - Which Region/Zone is default for creating resources.
- **Use Case:** By creating multiple configurations (like `dev` and `prod`), you can quickly switch your terminal's context without having to manually specify `--project=my-prod-project` on every single command.

## 3. Identity and Access Management (IAM)
IAM answers the question: *Who* can do *What* on *Which* resource?

### Service Accounts
- Regular user accounts (like `atharva@gmail.com`) are for human beings.
- **Service Accounts** are for machines. If you have a web server that needs to read an image from a Cloud Storage bucket, you give the web server a Service Account, and you give that Service Account permission to read the bucket.
- This ensures applications only have the exact permissions they need to function (Principle of Least Privilege) without relying on a human's credentials.

### Roles and Permissions
A **Permission** is a specific action (e.g., `storage.objects.get`).
A **Role** is a collection of permissions. You do not grant users permissions directly; you grant them roles.

- **Predefined Roles:** Created and managed by Google. They cover common use cases (e.g., `roles/storage.objectViewer` gives read access to storage buckets).
- **Custom Roles:** Created by you. If a predefined role gives too much access, you can create a custom role with a hyper-specific list of permissions (e.g., a role that *only* allows listing objects, but not downloading them).

### Policy Bindings
A **Binding** is the act of tying an Identity (like a Service Account) to a Role on a specific Resource (like a Project).
- Example: Binding `ace-deployer` (Identity) to `roles/compute.instanceAdmin.v1` (Role) on `ace-lab-prod-2026` (Resource).

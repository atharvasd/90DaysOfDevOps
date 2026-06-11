# GCP Associate Cloud Engineer — Hands-on Labs

This directory contains **18 production-style, hands-on labs** designed to prepare you for the **Google Cloud Associate Cloud Engineer (ACE)** certification and build real-world GCP + Kubernetes + Terraform expertise.

> **All commands use the latest GCP SDK syntax and modern best practices as of 2026.** Deprecated tools (`gsutil`, `gcr.io`, 1st Gen Cloud Functions, `kubernetes.io/ingress.class` annotation) have been replaced with their modern equivalents.

---

## 📋 Lab Index

### Domain 1 & 5: Setting Up Environment & Access/Security
| Lab | Topic | File |
|-----|-------|------|
| 01 | IAM, Projects, and gcloud CLI Configuration | [lab-01](./lab-01-iam-projects-gcloud-cli.md) |

### Domain 2: Planning and Configuring
| Lab | Topic | File |
|-----|-------|------|
| 02 | Custom VPC Networks and Compute Engine | [lab-02](./lab-02-vpc-networks-compute-engine.md) |
| 14 | VPC Peering, Shared VPC & Cloud SQL Private IP | [lab-14](./lab-14-vpc-peering-cloud-sql-private.md) |

### Domain 3: Deploying and Implementing
| Lab | Topic | File |
|-----|-------|------|
| 03 | Google Kubernetes Engine (GKE) Deployments | [lab-03](./lab-03-gke-deployments.md) |
| 04 | Serverless — Cloud Run & Cloud Functions (2nd Gen) | [lab-04](./lab-04-serverless-cloud-run-functions.md) |
| 05 | Cloud Storage & Cloud SQL Databases | [lab-05](./lab-05-cloud-storage-cloud-sql.md) |
| 11 | Cloud Pub/Sub — Asynchronous Messaging | [lab-11](./lab-11-cloud-pubsub-messaging.md) |
| 12 | Managed Instance Groups, Templates & Autoscaling | [lab-12](./lab-12-managed-instance-groups-autoscaling.md) |


### Domain 4: Ensuring Successful Operation
| Lab | Topic | File |
|-----|-------|------|
| 06 | Cloud Monitoring, Logging & Audit Trails | [lab-06](./lab-06-monitoring-logging-audit.md) |
| 13 | Snapshots, Custom Images & Disk Management | [lab-13](./lab-13-snapshots-images-disk-management.md) |
| 16 | GKE Cluster Upgrades & Node Pool Management | [lab-16](./lab-16-gke-upgrades-node-pool-management.md) |

### Advanced: Production GKE & Security
| Lab | Topic | File |
|-----|-------|------|
| 07 | Private GKE Clusters & Cloud NAT | [lab-07](./lab-07-private-gke-cloud-nat.md) |
| 08 | GKE Workload Identity & Secret Manager | [lab-08](./lab-08-workload-identity-secret-manager.md) |
| 09 | Cloud Build Pipelines & Artifact Registry | [lab-09](./lab-09-cloud-build-artifact-registry.md) |
| 10 | GKE Ingress & GCP Load Balancing | [lab-10](./lab-10-gke-ingress-load-balancing.md) |
| 15 | GKE Network Policies — Pod-to-Pod Isolation | [lab-15](./lab-15-gke-network-policies.md) |


### 🛡️ Security Best Practices (Production Hardening)
| Guide | Topics Covered | File |
|-------|---------------|------|
| GCP Security | IAM, networking, data protection, VPC Service Controls, KMS | [security-gcp](./security-best-practices-gcp.md) |


---

## 🗺️ ACE Exam Domain Coverage

| Exam Domain | Labs |
|---|---|
| 1. Setting up a cloud solution environment | 01 |
| 2. Planning and configuring a cloud solution | 02, 05, 14 |
| 3. Deploying and implementing a cloud solution | 03, 04, 05, 11, 12 |
| 4. Ensuring successful operation | 06, 13, 16 |
| 5. Configuring access and security | 01, 07, 08, 14, 15 |

---

## 🚀 Recommended Learning Path

```
Start Here
    │
    ├── Lab 01: IAM & gcloud CLI (foundation)
    ├── Lab 02: VPC & Compute Engine (networking)
    ├── Lab 05: Cloud Storage & Cloud SQL (data)
    │
    ├── Lab 03: GKE Deployments (K8s basics)
    ├── Lab 04: Serverless (Cloud Run + Functions)
    ├── Lab 11: Pub/Sub (event-driven)
    ├── Lab 12: MIGs & Autoscaling (VM scaling)
    │
    ├── Lab 06: Monitoring & Logging (operations)
    ├── Lab 13: Snapshots & Images (backup)
    │
    ├── Lab 07: Private GKE + Cloud NAT (security)
    ├── Lab 08: Workload Identity (keyless auth)
    ├── Lab 14: VPC Peering + Private SQL (networking)
    ├── Lab 15: Network Policies (pod security)
    │
    ├── Lab 09: Cloud Build (CI/CD)
    ├── Lab 10: GKE Ingress (load balancing)
    ├── Lab 16: GKE Upgrades (operations)
    │
    └── Lab 17-18: Terraform (IaC)
         └── Take the ACE Exam! 🎓
```

---

## ⚠️ Important Notes

- **Costs:** These labs create billable GCP resources. Each lab includes a cleanup section — **always run it** when finished.
- **Free Tier:** Use `e2-micro` VMs and `db-f1-micro` Cloud SQL instances to stay within free tier limits where possible.
- **Project:** Create a dedicated project for these labs so you can delete the entire project when done.
- **Modern CLI:** All commands use `gcloud storage` (not `gsutil`), Artifact Registry (not Container Registry), and Cloud Functions 2nd Gen (not 1st Gen).

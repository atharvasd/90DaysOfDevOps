# GCP Security Best Practices — Production Hardening Guide

A comprehensive checklist of security best practices for Google Cloud Platform, covering IAM, networking, data protection, and operational security.

---

## 🔐 1. Identity and Access Management (IAM)

### Principle of Least Privilege
```bash
# ❌ BAD: Giving Owner/Editor role (too broad)
gcloud projects add-iam-policy-binding my-project \
    --member="user:dev@company.com" --role="roles/owner"

# ✅ GOOD: Give only the specific permissions needed
gcloud projects add-iam-policy-binding my-project \
    --member="user:dev@company.com" --role="roles/storage.objectViewer"
```

### Use Custom Roles for Fine-Grained Control
```bash
# Create a custom role with only specific permissions
gcloud iam roles create customAppDeployer \
    --project=my-project \
    --title="App Deployer" \
    --permissions=run.services.create,run.services.update,run.services.get \
    --stage=GA
```

### Avoid User Accounts for Applications
```bash
# ❌ BAD: Using user credentials in applications
gcloud auth application-default login  # For local dev only, NEVER in production

# ✅ GOOD: Use Service Accounts with Workload Identity
gcloud iam service-accounts create app-sa \
    --display-name="Application Service Account"

# Bind minimal roles to the service account
gcloud projects add-iam-policy-binding my-project \
    --member="serviceAccount:app-sa@my-project.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"
```

### Never Export Service Account Keys
```bash
# ❌ BAD: Creating and downloading JSON key files
gcloud iam service-accounts keys create key.json \
    --iam-account=app-sa@my-project.iam.gserviceaccount.com
# JSON keys are static, don't expire, and are the #1 cause of GCP credential leaks

# ✅ GOOD: Use Workload Identity Federation instead
# For GKE: Workload Identity (KSA → GSA)
# For GitHub Actions / GitLab CI: Workload Identity Federation (OIDC)
# For GCE: Attached Service Accounts (metadata server)
```

### Enable Organization Policies
```bash
# Disable service account key creation across the org
gcloud org-policies set-policy --organization=<ORG_ID> policy.yaml
```
```yaml
# policy.yaml — block SA key creation
constraint: iam.disableServiceAccountKeyCreation
booleanPolicy:
  enforced: true
```

### Use IAM Conditions for Context-Aware Access
```bash
# Grant access only during business hours from corporate IP
gcloud projects add-iam-policy-binding my-project \
    --member="user:dev@company.com" \
    --role="roles/compute.viewer" \
    --condition='expression=request.time.getHours("America/New_York") >= 9 && request.time.getHours("America/New_York") <= 17,title=business-hours-only'
```

---

## 🌐 2. Network Security

### Use Private IPs Everywhere
```bash
# ✅ GKE: Private cluster (nodes have no public IPs)
gcloud container clusters create prod-cluster \
    --enable-private-nodes \
    --master-ipv4-cidr=172.16.0.0/28 \
    --enable-ip-alias

# ✅ Cloud SQL: Private IP only
gcloud sql instances create prod-db \
    --network=prod-vpc --no-assign-ip

# ✅ GCE: No external IP (use IAP for SSH)
gcloud compute instances create prod-vm \
    --no-address \
    --subnet=private-subnet
```

### Use Identity-Aware Proxy (IAP) Instead of SSH Keys
```bash
# ❌ BAD: Opening port 22 to the internet
gcloud compute firewall-rules create allow-ssh \
    --allow=tcp:22 --source-ranges=0.0.0.0/0

# ✅ GOOD: Use IAP tunneling (no open ports needed)
gcloud compute ssh prod-vm --zone=us-east1-b --tunnel-through-iap

# Allow only IAP's IP range for SSH
gcloud compute firewall-rules create allow-iap-ssh \
    --network=prod-vpc \
    --allow=tcp:22 \
    --source-ranges=35.235.240.0/20  # IAP's IP range
```

### VPC Firewall Best Practices
```bash
# ✅ Always use target tags (never apply rules to all instances)
gcloud compute firewall-rules create allow-http-web \
    --network=prod-vpc \
    --allow=tcp:80,tcp:443 \
    --target-tags=web-server \
    --source-ranges=0.0.0.0/0

# ✅ Restrict internal communication to necessary subnets only
gcloud compute firewall-rules create allow-app-to-db \
    --network=prod-vpc \
    --allow=tcp:3306 \
    --target-tags=database \
    --source-tags=app-server

# ✅ Create explicit deny rules for logging unauthorized access
gcloud compute firewall-rules create deny-all-log \
    --network=prod-vpc \
    --action=DENY --rules=all \
    --priority=65534 \
    --enable-logging
```

### Enable VPC Flow Logs
```bash
gcloud compute networks subnets update prod-subnet \
    --region=us-east1 \
    --enable-flow-logs \
    --logging-flow-sampling=0.5 \
    --logging-metadata=include-all
```

### Use VPC Service Controls for Data Exfiltration Prevention
```bash
# Create a service perimeter around sensitive projects
gcloud access-context-manager perimeters create prod-perimeter \
    --title="Production Perimeter" \
    --resources=projects/<PROJECT_NUMBER> \
    --restricted-services=storage.googleapis.com,bigquery.googleapis.com \
    --policy=<ACCESS_POLICY_ID>
```

---

## 🗄️ 3. Data Protection

### Encrypt Everything at Rest
```bash
# ✅ Default encryption: All GCP data is encrypted at rest with Google-managed keys
# For sensitive data, use Customer-Managed Encryption Keys (CMEK):

# Create a Cloud KMS key ring and key
gcloud kms keyrings create prod-keyring --location=us-east1
gcloud kms keys create prod-key \
    --location=us-east1 \
    --keyring=prod-keyring \
    --purpose=encryption

# Use CMEK with Cloud Storage
gcloud storage buckets create gs://sensitive-data-bucket \
    --location=us-east1 \
    --default-encryption-key=projects/my-project/locations/us-east1/keyRings/prod-keyring/cryptoKeys/prod-key

# Use CMEK with Cloud SQL
gcloud sql instances create prod-db \
    --disk-encryption-key=projects/my-project/locations/us-east1/keyRings/prod-keyring/cryptoKeys/prod-key
```

### Use Secret Manager (Never Hardcode Secrets)
```bash
# ❌ BAD: Hardcoding secrets in code, env files, or Terraform
DB_PASSWORD="SuperSecret123"

# ✅ GOOD: Store in Secret Manager
echo -n "SuperSecret123" | gcloud secrets versions add db-password --data-file=-

# Access in application code (Python example)
# from google.cloud import secretmanager
# client = secretmanager.SecretManagerServiceClient()
# response = client.access_secret_version(name="projects/my-project/secrets/db-password/versions/latest")
# password = response.payload.data.decode("UTF-8")
```

### Cloud Storage Security
```bash
# ✅ Enforce uniform bucket-level access (no legacy ACLs)
gcloud storage buckets update gs://my-bucket --uniform-bucket-level-access

# ✅ Enable object versioning for data protection
gcloud storage buckets update gs://my-bucket --versioning

# ✅ Block public access at org level
gcloud org-policies set-policy --organization=<ORG_ID> storage-policy.yaml
```

### Enable Audit Logging for Data Access
```bash
# Enable Data Access audit logs (they're OFF by default)
# Admin Activity logs are always on
gcloud projects get-iam-policy my-project --format=json > policy.json
# Add auditLogConfigs for relevant services, then:
gcloud projects set-iam-policy my-project policy.json
```

---

## 📊 4. Monitoring and Incident Response

### Enable Security Command Center (SCC)
```bash
# SCC is GCP's built-in security posture management tool
# It detects misconfigurations, vulnerabilities, and threats
# Enable via Console: Security > Security Command Center

# Query findings via CLI
gcloud scc findings list organizations/<ORG_ID> \
    --source="-" \
    --filter="state=\"ACTIVE\" AND severity=\"HIGH\""
```

### Set Up Alerts for Suspicious Activity
```bash
# Alert on IAM policy changes
gcloud logging metrics create iam-policy-changes \
    --description="Detects IAM policy modifications" \
    --log-filter='protoPayload.methodName="SetIamPolicy"'

# Alert on service account key creation
gcloud logging metrics create sa-key-creation \
    --description="Detects service account key creation" \
    --log-filter='protoPayload.methodName="google.iam.admin.v1.CreateServiceAccountKey"'

# Alert on firewall rule changes
gcloud logging metrics create firewall-changes \
    --description="Detects firewall rule modifications" \
    --log-filter='resource.type="gce_firewall_rule" AND protoPayload.methodName:"firewalls"'
```

### Export Logs for Long-Term Retention
```bash
# Export all audit logs to Cloud Storage (for compliance)
gcloud logging sinks create audit-archive \
    storage.googleapis.com/audit-logs-archive-bucket \
    --log-filter='logName:"cloudaudit.googleapis.com"'
```

---

## 🛡️ 5. Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **IAM** | Use Workload Identity instead of SA keys | 🔴 Critical |
| **IAM** | Apply least-privilege roles, never Owner/Editor | 🔴 Critical |
| **IAM** | Enable MFA for all user accounts | 🔴 Critical |
| **IAM** | Audit IAM policies quarterly | 🟡 High |
| **IAM** | Use IAM Conditions for context-aware access | 🟢 Medium |
| **Network** | Use private GKE clusters | 🔴 Critical |
| **Network** | Use IAP for SSH (not open port 22) | 🔴 Critical |
| **Network** | Enable VPC Flow Logs | 🟡 High |
| **Network** | Use VPC Service Controls for sensitive data | 🟡 High |
| **Network** | Restrict firewall rules with target tags | 🟡 High |
| **Data** | Use Secret Manager for all credentials | 🔴 Critical |
| **Data** | Enable CMEK for sensitive data | 🟡 High |
| **Data** | Enforce uniform bucket-level access | 🟡 High |
| **Data** | Block public access to storage | 🔴 Critical |
| **Ops** | Enable Security Command Center | 🟡 High |
| **Ops** | Set up alerts for IAM/firewall changes | 🟡 High |
| **Ops** | Export audit logs for compliance | 🟡 High |
| **Ops** | Run `gcloud asset search-all-iam-policies` quarterly | 🟢 Medium |

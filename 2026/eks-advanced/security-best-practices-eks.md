# Amazon EKS Security Best Practices

A guide to securing the control plane, worker nodes, and IAM integrations for Amazon Elastic Kubernetes Service (EKS).

---

## 🛑 1. IAM Roles for Service Accounts (IRSA)

Historically, if a Pod needed to upload a file to S3, you had to attach an IAM role to the entire EC2 Worker Node. This meant *every* Pod on that node could access S3!

### The Fix: IRSA (OIDC)
EKS supports OIDC federation. You can map an AWS IAM Role directly to a Kubernetes `ServiceAccount`.

1. **Create an IAM Policy and Role.**
2. **Establish trust between the Role and the EKS OIDC Provider.**
3. **Annotate the Kubernetes ServiceAccount:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-uploader-sa
  namespace: my-app
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/S3UploaderRole
```

Now, only Pods configured with `serviceAccountName: s3-uploader-sa` get AWS credentials.

---

## 🔐 2. Enable Secret Encryption (Envelope Encryption)

By default, Kubernetes Secrets are stored in the `etcd` database as base64 encoded plaintext. While AWS encrypts the EBS volumes underlying the EKS control plane (data at rest), anyone with administrative access to the API server or `etcd` backups can read the secrets.

### The Fix: AWS KMS Envelope Encryption
Enable envelope encryption during EKS cluster creation. This encrypts the secrets *inside* `etcd` using an AWS Key Management Service (KMS) key.

```bash
# Example AWS CLI cluster creation with KMS
aws eks create-cluster \
  --name my-secure-cluster \
  --role-arn arn:aws:iam::111122223333:role/eks-service-role-AWSServiceRoleForAmazonEKS-J7ONKE3BQ4PI \
  --resources-vpc-config subnetIds=subnet-a9189ed2,subnet-8761f0ce,securityGroupIds=sg-0210286b \
  --encryption-config '[{"resources":["secrets"],"provider":{"keyArn":"arn:aws:kms:us-west-2:111122223333:key/arn:aws:kms:us-west-2:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"}}]'
```

---

## 🌐 3. Restrict Control Plane Access

When you create an EKS cluster, the API Server endpoint is public by default. While protected by IAM authentication, exposing the API server to the entire internet is a risk.

### The Fix: Private Endpoints
Configure your EKS cluster endpoint access to be **Private Only** or **Public with restricted IP ranges**.

1. **Private Access:** The API server is only accessible from within your VPC (e.g., via a Bastion host or VPN).
2. **Public (Restricted):** Limit the Public Access CIDRs to your corporate office VPN IP range.

---

## 🛡️ Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **IAM** | Use IRSA for pod-level AWS permissions. Never attach app policies to Node IAM roles. | 🔴 Critical |
| **Network** | Restrict public access to the EKS API server endpoint. | 🔴 Critical |
| **Data** | Enable AWS KMS envelope encryption for Kubernetes Secrets. | 🔴 Critical |
| **Compute** | Use managed node groups or Karpenter with up-to-date AMIs to ensure OS-level CVEs are patched. | 🟡 High |
| **Network** | Use AWS Security Groups for Pods if strict network isolation is required per-application. | 🟡 High |

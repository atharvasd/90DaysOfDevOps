# Advanced EKS & Security

This directory covers advanced node autoscaling using Karpenter and AWS-specific security hardening for your Elastic Kubernetes Service clusters.

---

## 📋 Directory Contents

### Advanced Autoscaling
| Lab | Topic | File |
|-----|-------|------|
| Lab 01 | Karpenter Node Autoscaling | [lab-01](./lab-01-karpenter.md) |

### 🛡️ Security Best Practices
| Guide | Topics Covered | File |
|-------|---------------|------|
| EKS Security | IRSA (OIDC), KMS Envelope Encryption, Private API Endpoints | [security-eks](./security-best-practices-eks.md) |

---

## 🚀 Recommended Learning Path

1. Complete the core EKS curriculum (Days 81-83).
2. Complete **Lab 01** to understand why the industry is moving away from the standard Cluster Autoscaler in favor of Karpenter's rapid provisioning.
3. Review the **EKS Security Best Practices** guide. This is mandatory reading before provisioning any production EKS cluster on AWS to prevent massive credential leaks and data exposure.

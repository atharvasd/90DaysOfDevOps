# Advanced GitOps & Security

This directory covers enterprise GitOps scaling patterns and the critical security protocols required when storing cluster state in Git.

---

## 📋 Directory Contents

### Advanced GitOps Patterns
| Lab | Topic | File |
|-----|-------|------|
| Lab 01 | The App of Apps Pattern & ApplicationSets | [lab-01](./lab-01-app-of-apps.md) |

### 🛡️ Security Best Practices
| Guide | Topics Covered | File |
|-------|---------------|------|
| GitOps Security | Encrypting secrets in Git (SOPS/Sealed Secrets), SSO integration, Declarative RBAC | [security-gitops](./security-best-practices-gitops.md) |

---

## 🚀 Recommended Learning Path

1. Complete the core ArgoCD/GitOps curriculum (Days 84-86).
2. Complete **Lab 01** to learn how to manage dozens of microservices and hundreds of clusters using advanced ArgoCD generators without clicking through the UI.
3. Review the **GitOps Security Best Practices** guide. This is mandatory reading. Storing Kubernetes Secrets in plaintext in Git is the #1 mistake new GitOps engineers make.

# Advanced Terraform & Best Practices

This directory contains advanced Terraform concepts, configuration refactoring guides, and production security hardening standards that extend beyond the core TerraWeek curriculum.

---

## 📋 Directory Contents

### Advanced Configuration
| Lab | Topic | File |
|-----|-------|------|
| Lab 01 | Meta-Arguments (`count`, `for_each`, `dynamic`, `lifecycle`) | [lab-01](./lab-01-terraform-advanced-meta-arguments.md) |
| Lab 02 | Terraform Import Block (Declarative — v1.5+) | [lab-02](./lab-02-terraform-import-block.md) |
| Lab 03 | Terraform GKE Module — Production Cluster IaC | [lab-03](./lab-03-terraform-gke-module.md) |

### 🛡️ Security Best Practices
| Guide | Topics Covered | File |
|-------|---------------|------|
| Terraform Security | State protection, secrets management, policy enforcement, CI/CD | [security-terraform](./security-best-practices-terraform.md) |

---

## 🚀 Recommended Learning Path

1. Complete the core TerraWeek curriculum (Days 61-67).
2. Complete **Lab 01** to master advanced HCL meta-arguments which are critical for DRY (Don't Repeat Yourself) code.
3. Complete **Lab 02** to learn the modern, declarative way to bring existing infrastructure into state.
4. Review **Lab 03** to see how official, complex registry modules are structured and implemented.
5. Read and apply the **Terraform Security Best Practices** guide before running Terraform in a production CI/CD environment.

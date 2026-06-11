# Advanced Helm & Security

This directory covers advanced Helm features like Hooks, subchart dependency management, and securing your templated deployments.

---

## 📋 Directory Contents

### Advanced Helm Features
| Lab | Topic | File |
|-----|-------|------|
| Lab 01 | Writing Complex Helm Charts (Subcharts and Helpers) | [lab-01](./lab-01-complex-charts.md) |
| Lab 02 | Helm Hooks and Chart Testing | [lab-02](./lab-02-helm-hooks.md) |

### 🛡️ Security Best Practices
| Guide | Topics Covered | File |
|-------|---------------|------|
| Helm Security | Secret management, Provenance (Signing), Secure Context Defaults | [security-helm](./security-best-practices-helm.md) |

---

## 🚀 Recommended Learning Path

1. Complete the core Helm curriculum (Days 78-80).
2. Complete **Lab 01** to learn how to structure multi-tier enterprise applications using Helm subcharts.
3. Complete **Lab 02** to automate database migrations and integration testing during `helm install`.
4. Review the **Helm Security Best Practices** guide. This is critical to ensure you aren't leaking secrets into source control via `values.yaml`.

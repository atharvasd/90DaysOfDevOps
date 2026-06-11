# Helm Security Best Practices

A guide to securing Helm charts, preventing supply chain attacks, and keeping Kubernetes clusters safe from malicious deployments.

---

## 🛑 1. Never Store Secrets in Plaintext in `values.yaml`

It is common to see `database.password = "mypassword"` in a `values.yaml` file. If this file is committed to Git, the secret is compromised.

### The Fix: Externalize Secrets
Do not let Helm manage your secrets directly via standard Secrets resources generated from `values.yaml`. Instead:
1. Use an external secrets operator (like External Secrets Operator or Sealed Secrets) which Helm can template.
2. Inject secrets at deploy time via CI/CD (e.g., `helm install --set database.password=$SECRET_FROM_CI`).
3. (Best) Do not use Kubernetes Secrets at all; use CSI driver integrations with AWS Secrets Manager or HashiCorp Vault.

---

## 🔐 2. Verify Chart Provenance

When you run `helm install stable/mysql`, how do you know the chart hasn't been tampered with? A malicious actor could have modified the Deployment template to run a cryptominer.

### The Fix: Chart Signing and Provenance
Helm supports cryptographic signing of charts using GPG.

1. **Sign a chart (As a creator):**
```bash
helm package --sign --key 'My GPG Key' --keyring ~/.gnupg/secring.gpg my-chart/
```
*This generates a `my-chart.tgz` and a `my-chart.tgz.prov` (provenance file).*

2. **Verify a chart (As a user):**
Before installing a third-party chart, verify its signature.
```bash
helm verify my-chart-1.0.0.tgz
```

---

## 🛡️ 3. Ensure Strict `securityContext`

When writing a Helm chart, always provide secure defaults for the Pods it creates. Do not leave the `securityContext` blank.

### The Fix: Secure Defaults in `values.yaml`
```yaml
# values.yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

In your `deployment.yaml` template, ensure these values are applied:
```yaml
# templates/deployment.yaml
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
```

---

## 🛡️ Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **Secrets** | Never commit plaintext secrets in `values.yaml` | 🔴 Critical |
| **Defaults** | Always template a strict `securityContext` in your charts | 🔴 Critical |
| **Images** | Allow users to override the `image.tag` so they can patch CVEs without waiting for a chart update | 🟡 High |
| **Provenance**| Verify GPG signatures of critical third-party charts | 🟡 High |
| **Linting** | Run `helm lint` and `kube-linter` in CI/CD before publishing charts | 🟡 High |

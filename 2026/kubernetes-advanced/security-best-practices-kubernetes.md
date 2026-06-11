# Kubernetes Security Best Practices — Production Hardening Guide

A comprehensive guide to securing Kubernetes clusters, workloads, and supply chains. Covers RBAC, Pod Security, network isolation, secrets management, image security, and runtime protection.

---

## 🔐 1. RBAC (Role-Based Access Control)

### Never Use `cluster-admin` for Regular Users
```yaml
# ❌ BAD: Giving cluster-admin to a developer
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dev-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin  # Full access to everything — never do this
subjects:
- kind: User
  name: developer@company.com
```

```yaml
# ✅ GOOD: Namespace-scoped role with minimum permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-developer
  namespace: staging
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]  # Read-only secrets, no create/delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-app-developer
  namespace: staging
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-developer
subjects:
- kind: User
  name: developer@company.com
```

### Audit RBAC Permissions
```bash
# Check what a user can do
kubectl auth can-i --list --as=developer@company.com

# Check if a user can perform a specific action
kubectl auth can-i create deployments -n staging --as=developer@company.com

# Find all cluster-admin bindings (should be minimal)
kubectl get clusterrolebindings -o json | \
    jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name + " → " + (.subjects[]? | .name)'
```

---

## 🛡️ 2. Pod Security Standards (PSS)

Pod Security Standards replaced the deprecated PodSecurityPolicies (PSP) in K8s 1.25+. They enforce security at the namespace level.

### Enforce Restricted Security Standards
```bash
# Apply restricted standard to a namespace (strictest level)
kubectl label namespace production \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/warn=restricted \
    pod-security.kubernetes.io/audit=restricted
```

### Write Security-Hardened Pod Specs
```yaml
# ✅ Production-grade secure Pod spec
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: production
spec:
  automountServiceAccountToken: false  # Don't mount SA token unless needed
  securityContext:
    runAsNonRoot: true                 # Never run as root
    runAsUser: 1000                    # Explicit non-root UID
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault             # Enable seccomp filtering
  containers:
  - name: app
    image: myregistry/myapp:v1.2.3@sha256:abc123...  # Pin by digest
    securityContext:
      allowPrivilegeEscalation: false  # Block privilege escalation
      readOnlyRootFilesystem: true     # Prevent writes to container filesystem
      capabilities:
        drop: ["ALL"]                  # Drop ALL Linux capabilities
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: tmp
      mountPath: /tmp                  # Writable tmp dir (since rootfs is read-only)
  volumes:
  - name: tmp
    emptyDir: {}
```

### Common Security Context Mistakes
```yaml
# ❌ BAD: Running as root with all capabilities
securityContext:
  runAsUser: 0           # root!
  privileged: true       # Gives full host access
  capabilities:
    add: ["SYS_ADMIN"]   # Kernel-level access

# ❌ BAD: Writable root filesystem
securityContext:
  readOnlyRootFilesystem: false  # Allows malware to persist

# ❌ BAD: Automounting SA token when not needed
automountServiceAccountToken: true  # Default! Always set to false unless required
```

---

## 🌐 3. Network Security

### Default Deny All Traffic
```yaml
# Apply this to EVERY namespace as baseline
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}  # Matches all pods
  policyTypes:
  - Ingress
  - Egress
```

### Allow Only Required Traffic
```yaml
# Allow frontend to talk to backend API on port 8080
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend-api
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - port: 8080
      protocol: TCP
  # Allow DNS (required for service discovery)
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
  policyTypes:
  - Ingress
  - Egress
```

### Restrict Egress to Prevent Data Exfiltration
```yaml
# Block all outbound except DNS and specific services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restricted-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend-api
  egress:
  - to:  # Allow DNS
    - namespaceSelector: {}
    ports:
    - port: 53
      protocol: UDP
  - to:  # Allow only database pods
    - podSelector:
        matchLabels:
          app: database
    ports:
    - port: 5432
  policyTypes:
  - Egress
```

---

## 🔑 4. Secrets Management

### Never Store Secrets in Plain YAML
```yaml
# ❌ BAD: Secrets in manifests checked into Git
apiVersion: v1
kind: Secret
metadata:
  name: db-creds
stringData:
  password: "MyPlainTextPassword"  # This will be in your Git history forever!
```

### Use External Secrets Operator or Sealed Secrets
```bash
# Option 1: External Secrets Operator (pulls from GCP Secret Manager, AWS SM, Vault)
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

```yaml
# ExternalSecret — automatically syncs from GCP Secret Manager
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: db-password
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcp-secret-store
    kind: ClusterSecretStore
  target:
    name: db-creds
  data:
  - secretKey: password
    remoteRef:
      key: projects/my-project/secrets/db-password
```

### Enable Encryption at Rest for etcd
```yaml
# EncryptionConfiguration for kube-apiserver
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-encoded-32-byte-key>
  - identity: {}  # Fallback for reading unencrypted secrets
```

> **On GKE:** Application-layer encryption for secrets is enabled via:
> ```bash
> gcloud container clusters update my-cluster \
>     --database-encryption-key=projects/my-project/locations/us-east1/keyRings/ring/cryptoKeys/key
> ```

---

## 📦 5. Image and Supply Chain Security

### Use Distroless or Minimal Base Images
```dockerfile
# ❌ BAD: Full Ubuntu image (200+ MB, 100+ CVEs)
FROM ubuntu:22.04

# ✅ GOOD: Distroless (no shell, no package manager, minimal attack surface)
FROM gcr.io/distroless/java21-debian12

# ✅ GOOD: Alpine (5 MB, minimal packages)
FROM alpine:3.20
```

### Pin Images by SHA256 Digest
```yaml
# ❌ BAD: Mutable tag (could be overwritten with malicious image)
image: nginx:latest

# ❌ BAD: Even named tags are mutable
image: nginx:1.27

# ✅ GOOD: Immutable digest — guarantees exact image bytes
image: nginx:1.27@sha256:6db391d1c0cfb30588ba0bf72ea999404f2764deadd21a064f9885dc583def57
```

### Scan Images for Vulnerabilities
```bash
# Scan with Trivy (open source)
trivy image myregistry/myapp:v1.2.3

# Scan with GCP Artifact Registry (built-in)
gcloud artifacts docker images list-vulnerabilities \
    us-east1-docker.pkg.dev/my-project/repo/myapp@sha256:abc123

# Enforce scanning in CI/CD (fail build on HIGH/CRITICAL CVEs)
trivy image --exit-code 1 --severity HIGH,CRITICAL myregistry/myapp:v1.2.3
```

### Use Binary Authorization (GKE)
```bash
# Only allow images signed by your CI/CD pipeline to run on GKE
gcloud container clusters update my-cluster \
    --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE
```

---

## 🏥 6. Runtime Security

### Resource Limits (Prevent Resource Exhaustion DoS)
```yaml
# ✅ Always set both requests AND limits
resources:
  requests:
    cpu: 100m       # Guaranteed minimum
    memory: 128Mi
  limits:
    cpu: 500m       # Hard cap
    memory: 256Mi   # OOMKilled if exceeded
```

### Limit Blast Radius with Namespaces + Resource Quotas
```yaml
# Prevent one team from consuming all cluster resources
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a-quota
  namespace: team-a
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
    secrets: "10"
```

### Use Pod Disruption Budgets
```yaml
# Ensure minimum availability during upgrades/maintenance
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
  namespace: production
spec:
  minAvailable: 2  # At least 2 replicas must be running at all times
  selector:
    matchLabels:
      app: backend-api
```

---

## 🛡️ 7. Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **RBAC** | No cluster-admin for regular users | 🔴 Critical |
| **RBAC** | Use namespace-scoped Roles, not ClusterRoles | 🔴 Critical |
| **RBAC** | Audit `kubectl auth can-i --list` quarterly | 🟡 High |
| **Pods** | `runAsNonRoot: true` on all containers | 🔴 Critical |
| **Pods** | `readOnlyRootFilesystem: true` | 🔴 Critical |
| **Pods** | `allowPrivilegeEscalation: false` | 🔴 Critical |
| **Pods** | Drop ALL capabilities | 🔴 Critical |
| **Pods** | `automountServiceAccountToken: false` unless needed | 🟡 High |
| **Pods** | Set CPU/memory requests AND limits | 🟡 High |
| **Network** | Default deny-all NetworkPolicy per namespace | 🔴 Critical |
| **Network** | Explicit allow rules for required traffic only | 🔴 Critical |
| **Network** | Restrict egress to prevent exfiltration | 🟡 High |
| **Secrets** | Never store secrets in Git | 🔴 Critical |
| **Secrets** | Use External Secrets Operator or Sealed Secrets | 🔴 Critical |
| **Secrets** | Enable encryption at rest for etcd | 🟡 High |
| **Images** | Pin images by SHA256 digest | 🟡 High |
| **Images** | Scan images in CI/CD pipeline | 🔴 Critical |
| **Images** | Use distroless/minimal base images | 🟡 High |
| **Runtime** | Set ResourceQuotas per namespace | 🟡 High |
| **Runtime** | Use PodDisruptionBudgets for critical workloads | 🟢 Medium |
| **GKE** | Enable Binary Authorization | 🟢 Medium |
| **GKE** | Enable Workload Identity (no SA keys in pods) | 🔴 Critical |

# GitOps Security Best Practices

A guide to securing ArgoCD, handling secrets in Git, and ensuring strict declarative access controls.

---

## 🛑 1. Never Store Plaintext Secrets in Git

GitOps means your entire cluster state is in Git. If you commit a Kubernetes `Secret.yaml` file containing plaintext or base64-encoded API keys, your repository is compromised.

### The Fix: Sealed Secrets or SOPS

You must encrypt the secret *before* it enters Git. 

**Using Bitnami Sealed Secrets:**
1. Install the Sealed Secrets controller in your cluster. It generates an asymmetric keypair.
2. Use the `kubeseal` CLI on your laptop to encrypt your secret using the public key.
3. Commit the resulting `SealedSecret` custom resource to Git.
4. ArgoCD syncs the `SealedSecret` to the cluster.
5. The Sealed Secrets controller decrypts it using its private key and generates the native Kubernetes `Secret`.

---

## 🔐 2. Disable Local ArgoCD Admin

By default, ArgoCD provisions a local `admin` user with a password. This is bad for auditing, as you don't know *which* human actually logged in.

### The Fix: SSO Integration (OIDC)
Configure ArgoCD to use your corporate Identity Provider (Google Workspace, GitHub, Azure AD, Okta) via OIDC or SAML.

```yaml
# In the argocd-cm ConfigMap
data:
  dex.config: |
    connectors:
      - type: github
        id: github
        name: GitHub
        config:
          clientID: $argocd-github-client-id
          clientSecret: $argocd-github-client-secret
          orgs:
          - name: my-company
```

After verifying SSO works, disable the local admin user entirely:
```yaml
# In the argocd-cm ConfigMap
data:
  admin.enabled: "false"
```

---

## 🛡️ 3. Declarative RBAC

ArgoCD allows you to define who can sync or delete specific applications. This should be managed declaratively in Git, not via the UI.

### The Fix: `argocd-rbac-cm`
Map your SSO groups to ArgoCD roles.

```yaml
# In the argocd-rbac-cm ConfigMap
data:
  policy.csv: |
    # Give the Dev team read-only access to all apps
    p, role:developer, applications, get, *, allow
    
    # Give the Dev team sync (deploy) access ONLY to the "dev-project"
    p, role:developer, applications, sync, dev-project/*, allow
    
    # Map the GitHub team to the role
    g, my-company:developers, role:developer
    
    # Give DevOps full admin
    g, my-company:devops, role:admin
```

---

## 🛡️ Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **Secrets** | Encrypt secrets using SOPS or Sealed Secrets before committing to Git | 🔴 Critical |
| **Identity** | Integrate ArgoCD with SSO (GitHub, Google, Okta) | 🔴 Critical |
| **Identity** | Disable the local `admin` user (`admin.enabled: "false"`) | 🔴 Critical |
| **RBAC** | Define declarative RBAC mapped to SSO groups | 🟡 High |
| **Network** | Do not expose the ArgoCD UI directly to the public internet without an Identity-Aware Proxy | 🟡 High |

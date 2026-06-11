# Lab 01: The App of Apps Pattern & ApplicationSets

**Topic:** Advanced GitOps

---

## Overview

In basic ArgoCD tutorials, you create one `Application` resource via the UI or CLI that points to a Git repository. 

But what if your cluster requires 20 applications (Prometheus, Grafana, Nginx Ingress, Cert-Manager, and 16 microservices)? Creating them one by one is not GitOps. 

The **App of Apps** pattern uses a single "Root" ArgoCD Application that points to a Git folder containing the YAML definitions for *other* ArgoCD Applications. When you sync the Root App, ArgoCD automatically discovers and syncs the child apps!

---

## 🛠️ Hands-on Tasks

### Task 1: Create the Child Applications in Git

Imagine your Git repository looks like this:
```text
argocd-config/
├── apps/
│   ├── prometheus.yaml
│   ├── ingress-nginx.yaml
│   └── frontend-app.yaml
```

**`apps/prometheus.yaml`**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: prometheus
    targetRevision: 15.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Task 2: Create the Root "App of Apps"

Now you create one single file to rule them all.

**`root-app.yaml`**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/my-org/my-gitops-repo.git
    targetRevision: HEAD
    # Point this to the folder containing your child Applications
    path: argocd-config/apps 
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Task 3: Bootstrap the Cluster

The only manual step you ever have to take on a fresh cluster:

```bash
kubectl apply -f root-app.yaml
```

ArgoCD will read `root-app.yaml`, reach out to Git, find `prometheus.yaml`, dynamically create a new ArgoCD Application for Prometheus, and then deploy the Prometheus Helm chart.

### Task 4: ApplicationSets (The Modern App of Apps)

If you manage 5 different clusters (dev, staging, prod-eu, prod-us), maintaining 5 different `root-apps` is tedious. **ApplicationSets** generate ArgoCD Applications dynamically based on generators (like a list of clusters).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook
  namespace: argocd
spec:
  # The generator provides parameters (like {{cluster}}) to the template
  generators:
  - list:
      elements:
      - cluster: dev-cluster
        url: https://1.2.3.4
      - cluster: prod-cluster
        url: https://5.6.7.8
  template:
    metadata:
      name: '{{cluster}}-guestbook'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: guestbook
      destination:
        server: '{{url}}'
        namespace: guestbook
```

---

## ✅ Best Practices
- **Never modify child apps in the UI:** If you use the App of Apps pattern, editing a child application via the ArgoCD UI will immediately be overwritten by the Root App's self-healing mechanism. Change the configuration in Git!
- **Cascade Deletion:** By default, deleting the Root App will delete all child apps AND all their deployed resources. Be very careful.

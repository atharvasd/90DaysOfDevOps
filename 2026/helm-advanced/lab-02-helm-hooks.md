# Lab 02: Helm Hooks and Chart Testing

**Topic:** Advanced Helm

---

## Overview

When you run `helm install`, you might need certain tasks to run *before* the application starts (like running database migrations), or *after* it starts (like running integration tests). 

**Helm Hooks** allow you to intervene at specific points in a release's lifecycle.

---

## 🛠️ Hands-on Tasks

### Task 1: Pre-Install Hook (Database Migrations)

Imagine your application requires a SQL database migration before the Deployment starts.

Create `templates/migration-job.yaml`:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: "{{ .Release.Name }}-db-migration"
  labels:
    app: {{ .Chart.Name }}
  annotations:
    # 🔴 This is the magic line. It tells Helm this is a hook!
    "helm.sh/hook": pre-install,pre-upgrade
    
    # Give it a high weight so it runs before other hooks (if any)
    "helm.sh/hook-weight": "-5"
    
    # Delete the job automatically after it succeeds so it doesn't clutter the cluster
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migration
        image: my-db-migrator:latest
        command: ["/run-migrations.sh"]
```

*When you run `helm install`, Helm will submit this Job to Kubernetes, **wait** for it to complete successfully, and only then proceed to apply the Deployments and Services.*

### Task 2: Helm Chart Tests

Helm has a built-in testing framework. You can define a Pod that runs tests against your deployed application.

Create `templates/tests/test-connection.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ .Release.Name }}-test-connection"
  annotations:
    # 🔴 This marks the Pod as a test
    "helm.sh/hook": test
spec:
  containers:
    - name: wget
      image: busybox
      # Try to reach the service created by the chart
      command: ['wget']
      args: ['{{ .Release.Name }}-myservice:80']
  restartPolicy: Never
```

### Task 3: Running the Tests

1. **Install the chart:**
```bash
helm install my-release ./my-chart
```

2. **Run the tests:**
```bash
helm test my-release
```
*Helm will spin up the test Pod. If the Pod exits with code 0 (the `wget` was successful), Helm reports the test as PASSED. If it exits with 1, the test FAILS.*

---

## ✅ Best Practices
- **Use `hook-delete-policy`:** Always configure your hooks to delete themselves (`hook-succeeded`, `before-hook-creation`). Otherwise, a failed migration Job will block all future `helm upgrade` attempts because the Job name already exists.
- **Idempotent Hooks:** Ensure your `pre-install` or `pre-upgrade` scripts are idempotent. If a migration fails halfway through and the hook runs again, it shouldn't corrupt the database.

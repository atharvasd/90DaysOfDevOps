# Day 60 Capstone Project: WordPress + MySQL

This document serves as the step-by-step lab notebook and architecture documentation for the Day 60 Kubernetes Capstone.

---

## 🏗️ Architecture Overview
*To be completed after deployment.*

---

## 📝 Task Log and Commands

### Task 1: Create the Namespace (Declarative)
We originally created the namespace via the CLI, but to follow professional GitOps standards, we deleted it and created it declaratively using `00-namespace.yaml`.

**Commands Executed:**
```bash
# Apply the declarative namespace
kubectl apply -f 00-namespace.yaml

# Set it as the default namespace for our terminal session
kubectl config set-context --current --namespace=capstone
```

### Task 2: Deploy MySQL

#### Step 2.1: Database Secret
We created a secret using `stringData` to store the database credentials securely without manually base64 encoding them.

**Commands Executed:**
```bash
# Apply all MySQL components
kubectl apply -f 01-mysql-secret.yaml
kubectl apply -f 02-mysql-headless-svc.yaml
kubectl apply -f 03-mysql-statefulset.yaml

# Verify StatefulSet initialization and persistent volume creation
kubectl get pods -w

# Verify the database was created successfully
kubectl exec -it mysql-statefull-set-0 -n capstone -- mysql -u phoenix1 -p'user#capstone' -e "SHOW DATABASES;"
```

**Verification:** Successfully connected to the pod and verified the `capstone-db` was initialized on the Persistent Volume.

### Task 3: Deploy WordPress
*(Waiting for your commands...)*

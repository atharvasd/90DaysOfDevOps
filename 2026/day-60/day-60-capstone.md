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
**Commands Executed:**
```bash
# Apply the frontend configuration and deployment
kubectl apply -f 04-wordpress-configmap.yaml
kubectl apply -f 05-wordpress-deployment.yaml

# Monitor the WordPress pods as they boot up and run their initialization scripts
kubectl get pods -n capstone -w
```

### Task 4: Expose WordPress
**Commands Executed:**
```bash
# Apply the NodePort Service
kubectl apply -f 06-wordpress-nodeport-svc.yaml

# Verify the service is running
kubectl get svc -n capstone

# Since we are using KIND (Kubernetes in Docker), we use port-forwarding to bypass the Docker network and access it on localhost
kubectl port-forward svc/wordpress 30080:80 -n capstone
```

**Verification:** Access the frontend at `http://localhost:30080` to view the WordPress installation screen!

### Task 5: Test Self-Healing and Persistence
**Commands Executed:**
```bash
# Intentionally delete the MySQL master pod to test resilience
kubectl delete pod mysql-0 -n capstone

# Watch Kubernetes automatically recreate it
kubectl get pods -n capstone -w
```
**Verification:** The `mysql-0` pod was recreated, automatically reattached to the Persistent Volume, and the WordPress site recovered with zero data loss!

### Task 6: Set Up HPA (Horizontal Pod Autoscaling)
*(Waiting for your commands...)*

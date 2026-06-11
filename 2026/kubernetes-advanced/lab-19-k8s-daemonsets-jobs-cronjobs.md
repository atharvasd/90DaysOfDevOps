# Lab 19: Advanced Kubernetes Workloads — DaemonSets, Jobs, and CronJobs

**Exam Domain:** Deploying and implementing a cloud solution (Kubernetes)

---

## Overview

While Deployments and StatefulSets are used for long-running services, Kubernetes provides specialized controllers for other types of workloads.

### Key Concepts
- **DaemonSet** — Ensures that a copy of a Pod runs on *every* node (or a subset of nodes) in the cluster. Used for cluster-level services like logging agents (Fluentd/Promtail), monitoring agents (Node Exporter), and network proxies (kube-proxy).
- **Job** — Creates one or more Pods and ensures that a specified number of them successfully terminate. Used for one-off tasks like database migrations, batch processing, or backups.
- **CronJob** — Creates Jobs on a repeating schedule. Uses standard Cron format. Ideal for periodic tasks like nightly backups or sending reports.

---

## 🛠️ Hands-on Tasks

### Task 1: Create a DaemonSet (Logging Agent)

Imagine you need to run a logging agent on every node in your cluster to collect host-level metrics.

```yaml
# k8s/daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:
      # This toleration allows it to run on the control plane/master nodes if they exist
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      # Terminate gracefully
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

```bash
# Apply the DaemonSet
kubectl apply -f k8s/daemonset.yaml

# Check the DaemonSet status
kubectl get daemonset -n kube-system fluentd-elasticsearch

# List the Pods — you should see exactly one Pod per Node
kubectl get pods -n kube-system -l name=fluentd-elasticsearch -o wide
```

### Task 2: Create a Job (Database Migration)

You need to run a one-time database migration script before your main application starts.

```yaml
# k8s/job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration-job
spec:
  # How many times to retry if the pod fails
  backoffLimit: 4
  # How long the job can run before being terminated (in seconds)
  activeDeadlineSeconds: 100
  template:
    spec:
      containers:
      - name: migration-worker
        image: busybox:latest
        command: ["/bin/sh",  "-c"]
        # Simulate a migration task taking 10 seconds
        args: ["echo 'Starting DB Migration...'; sleep 10; echo 'Migration Complete!'"]
      # Jobs must have a restartPolicy of Never or OnFailure (default is Always)
      restartPolicy: Never
```

```bash
# Apply the Job
kubectl apply -f k8s/job.yaml

# Watch the Job progress
kubectl get jobs -w

# Check the Pod created by the Job (Notice the status becomes 'Completed' instead of 'Running')
kubectl get pods -l job-name=db-migration-job

# Read the logs of the completed Pod
kubectl logs -l job-name=db-migration-job
```

### Task 3: Create a CronJob (Nightly Backup)

You want to run a database backup every night at 2:00 AM.

```yaml
# k8s/cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-backup-cronjob
spec:
  # Schedule format: Minute Hour DayOfMonth Month DayOfWeek
  schedule: "0 2 * * *"
  # How many completed jobs to keep for history
  successfulJobsHistoryLimit: 3
  # How many failed jobs to keep for history
  failedJobsHistoryLimit: 1
  # Prevent concurrent runs if the previous backup is still running
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup-worker
            image: busybox:latest
            command: ["/bin/sh", "-c"]
            args: ["echo 'Running nightly DB backup...'; date; sleep 5; echo 'Backup complete!'"]
          restartPolicy: OnFailure
```

```bash
# Apply the CronJob
kubectl apply -f k8s/cronjob.yaml

# List the CronJob
kubectl get cronjobs

# For testing purposes, manually trigger a Job from the CronJob right now (bypassing the schedule)
kubectl create job --from=cronjob/db-backup-cronjob manual-backup-001

# Watch the manually triggered Job complete
kubectl get jobs
kubectl logs -l job-name=manual-backup-001
```

---

## ✅ Verification

```bash
# Verify DaemonSet has desired = ready = number of nodes
kubectl get ds -n kube-system

# Verify Job completed successfully
kubectl get job db-migration-job

# Verify CronJob is scheduled
kubectl get cronjob db-backup-cronjob
```

---

## 🧹 Cleanup

```bash
kubectl delete -f k8s/cronjob.yaml
kubectl delete -f k8s/job.yaml
kubectl delete job manual-backup-001
kubectl delete -f k8s/daemonset.yaml
```

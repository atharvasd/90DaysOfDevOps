# Day 51 – Kubernetes Manifests and Your First Pods

## The Four Required Fields of a Kubernetes Manifest

Every Kubernetes resource is defined using a YAML file with four required top-level fields:

| Field | Purpose |
|---|---|
| `apiVersion` | Tells Kubernetes which API group and version to use. For Pods, this is `v1`. |
| `kind` | The type of resource to create. Today it is `Pod`. Others include `Deployment`, `Service`, `ConfigMap`, etc. |
| `metadata` | The identity of your resource. `name` is required. `labels` are optional key-value pairs used to organize and select resources. |
| `spec` | The desired state — what you actually want running. For a Pod, this includes which containers, images, ports, commands, and resource limits to use. |

---

## Pod Manifests

### 1. Nginx Pod (`nginx-pod.yaml`)

A simple web server pod using the official Nginx image.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
    - name: nginx-app1
      image: nginx:latest
      ports:
        - containerPort: 80
```

### 2. BusyBox Pod (`busybox-pod.yaml`)

A minimal pod that runs a one-time command and then sleeps to stay alive.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox-pod
  labels:
    app: busybox
    environment: dev

spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["sh","-c", "echo Hello from BusyBox && sleep 3600"]
```

> **Note:** Without the `sleep 3600` command, the container would exit immediately after printing and the pod would go into `CrashLoopBackOff`. BusyBox is not a long-lived server like Nginx, so the command must keep the container running.

### 3. Redis Pod (`redis-pod.yaml`)

A Redis pod with three labels demonstrating multi-label organization.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: redis-pod
  labels:
    app: redis
    environment: dev
    team: platform
spec:
  containers:
    - name: redis-container
      image: redis:latest
      ports:
        - containerPort: 6379
```

---

## Imperative vs Declarative

### Declarative (The Kubernetes Way)

You describe the **desired state** in a YAML file and tell Kubernetes to make it so. Kubernetes compares the current state with the desired state and reconciles any differences.

```bash
kubectl apply -f nginx-pod.yaml
```

- Repeatable and idempotent — running it twice has no side effects
- Source-controllable — your YAML lives in Git
- Recommended for production

### Imperative (The Quick Way)

You tell Kubernetes **what action to take** right now via a CLI command.

```bash
kubectl run redis-pod --image=redis:latest
```

- Fast for one-off tasks or debugging
- Not repeatable — hard to track what was done
- Kubernetes auto-generates the YAML behind the scenes (see below)

### What Kubernetes generates under the hood

When you run `kubectl run`, Kubernetes creates a full manifest internally. You can inspect it with:

```bash
kubectl get pod redis-pod -o yaml
```

Or generate a template without creating anything using dry-run:

```bash
kubectl run test-pod --image=nginx --dry-run=client -o yaml
```

**Example dry-run output (`dry-run.yaml`):**
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: test-pod
  name: test-pod
spec:
  containers:
    - image: nginx
      name: test-pod
      resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
```

Compare this with `nginx-pod.yaml` — Kubernetes adds `dnsPolicy`, `restartPolicy`, `resources`, and a `status` block automatically. Your hand-written manifest only needs the fields you care about.

---

## Validating Manifests Before Applying

There are three layers of validation:

| Method | Command | What it catches |
|---|---|---|
| YAML syntax | `yamllint file.yaml` | Bad indentation, missing colons |
| Schema (offline) | `kubeconform -strict file.yaml` | Unknown fields, wrong types |
| Cluster dry-run | `kubectl apply -f file.yaml --dry-run=server` | Full API server validation |

> **Key insight:** `--dry-run=client` is lenient and can miss unknown field typos (e.g., `img` instead of `image`). `--dry-run=server` runs the same validation the real apply does — always use this before applying to production.

---

## Pod Labels and Filtering

Labels are key-value pairs attached to resources. They have no meaning to Kubernetes itself — their power comes from **label selectors**, which allow other resources (like Services and Deployments) to find and connect to the right pods.

```bash
# List all pods with their labels
kubectl get pods --show-labels

# Filter pods by a specific label
kubectl get pods -l app=nginx
kubectl get pods -l environment=dev      # Returns busybox-pod AND redis-pod

# Add a label to a running pod
kubectl label pod nginx-pod environment=production

# Overwrite an existing label
kubectl label pod nginx-pod environment=staging --overwrite

# Remove a label (note the trailing dash)
kubectl label pod nginx-pod environment-
```

---

## What Happens When You Delete a Standalone Pod?

```bash
kubectl delete pod nginx-pod
```

**It is gone forever.** There is no controller watching standalone Pods. Once deleted, Kubernetes makes no attempt to recreate it.

This is the core reason why production workloads use **Deployments** instead of bare Pods. A Deployment wraps a Pod template inside a controller that constantly ensures the desired number of replicas are always running — if a pod dies, the controller automatically creates a new one.

> Day 52: You will create your first Deployment and see this controller behavior in action.

---

## Summary

| Concept | Key Takeaway |
|---|---|
| Manifest structure | Every resource needs `apiVersion`, `kind`, `metadata`, `spec` |
| Pods | Smallest deployable unit — one or more containers sharing network and storage |
| Declarative | Use `kubectl apply -f` with YAML files — repeatable and source-controllable |
| Imperative | Use `kubectl run` for quick tasks — Kubernetes generates the YAML internally |
| Labels | Key-value pairs for organizing and selecting resources |
| Standalone Pods | No self-healing — use Deployments in production |

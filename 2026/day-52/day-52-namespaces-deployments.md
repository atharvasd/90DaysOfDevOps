# Day 52 – Kubernetes Namespaces and Deployments

---

## What are Namespaces?

Namespaces are **virtual clusters inside your Kubernetes cluster**. They let you logically isolate resources — different teams, environments (dev/staging/prod), or applications can all share the same physical cluster without interfering with each other.

### Why use Namespaces?

- **Isolation:** Resources in one namespace cannot accidentally affect resources in another
- **Organization:** Group related resources together (e.g., all dev resources in `dev`)
- **Access control:** You can restrict who can access which namespace using RBAC
- **Resource quotas:** Limit CPU/memory usage per namespace

### Built-in Namespaces

| Namespace | Purpose |
|---|---|
| `default` | Where resources go if you don't specify a namespace |
| `kube-system` | Kubernetes internal control plane components — do not touch |
| `kube-public` | Publicly readable cluster info |
| `kube-node-lease` | Node heartbeat tracking for health checks |

**kube-system pods observed:**

```
NAME                                                   READY   STATUS
coredns-7d764666f9-6tp67                               1/1     Running   ← DNS resolution
coredns-7d764666f9-m4pdx                               1/1     Running   ← DNS (HA replica)
etcd-devops-cluster-control-plane                      1/1     Running   ← Cluster database
kindnet-q52qf                                          1/1     Running   ← Network plugin
kube-apiserver-devops-cluster-control-plane            1/1     Running   ← API gateway
kube-controller-manager-devops-cluster-control-plane   1/1     Running   ← Control loops
kube-proxy-9dshz                                       1/1     Running   ← Network rules
kube-scheduler-devops-cluster-control-plane            1/1     Running   ← Pod placement
```

---

## Creating Custom Namespaces

**Imperative:**
```bash
kubectl create namespace dev
kubectl create namespace staging
```

**Declarative (prod-namespace.yaml):**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
```
```bash
kubectl apply -f prod-namespace.yaml
```

**Key namespace commands:**
```bash
kubectl get pods -n dev        # Pods in a specific namespace
kubectl get pods -A            # Pods across ALL namespaces
kubectl get pods               # Only shows default namespace
```

> `kubectl get pods` without `-n` only shows the `default` namespace. This catches many beginners off guard.

---

## Deployment Manifest — Full Explanation

```yaml
apiVersion: apps/v1        # Deployments live in the 'apps' group, not core 'v1'
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: dev            # Scoped to the dev namespace
  labels:
    app: nginx
spec:
  replicas: 3               # Desired number of pod replicas
  selector:
    matchLabels:
      app: nginx            # This Deployment manages pods with this label
  template:                 # Blueprint used to create each pod
    metadata:
      labels:
        app: nginx          # MUST match selector.matchLabels
    spec:
      containers:
        - name: nginx
          image: nginx:1.24
          ports:
            - containerPort: 80
```

### Understanding the Deployment output

```
NAME               READY   UP-TO-DATE   AVAILABLE
nginx-deployment   3/3     3            3
```

| Column | Meaning |
|---|---|
| **READY** `3/3` | current/desired — pods that are ready |
| **UP-TO-DATE** `3` | Pods matching the latest template (changes during rolling updates) |
| **AVAILABLE** `3` | Pods that are healthy and serving traffic |

### Pod naming hierarchy

```
nginx-deployment-5d9c84579f-jbhsx
│                │           │
│                │           └── Random pod ID
│                └────────────── ReplicaSet hash (from pod template)
└─────────────────────────────── Deployment name
```

---

## Deployment vs Standalone Pod — Self-Healing

This is the most important difference between a Deployment and a bare Pod:

| Scenario | Standalone Pod | Deployment Pod |
|---|---|---|
| Pod deleted | Gone forever ❌ | Replaced in seconds ✅ |
| Node crashes | Gone forever ❌ | Rescheduled to another node ✅ |
| Container OOM killed | Gone forever ❌ | Restarted automatically ✅ |

**How it works — the reconciliation loop:**

```
1. Observe:  How many pods exist?   → 2
2. Desired:  How many should exist? → 3
3. Act:      Create 1 new pod
4. Repeat forever
```

The `kube-controller-manager` runs this loop continuously. You cannot permanently reduce the pod count by deleting pods — the Deployment will always recreate them.

> **Note:** The replacement pod gets a **new name** with a different random suffix. The ReplicaSet hash stays the same since the pod template didn't change.

---

## Scaling

### Imperative (quick, but not persistent)
```bash
kubectl scale deployment nginx-deployment --replicas=5 -n dev
kubectl scale deployment nginx-deployment --replicas=2 -n dev
```

### Declarative (recommended — edit YAML, then apply)
```bash
# Edit nginx-deployment.yaml: change replicas: 3 to replicas: 5
kubectl apply -f nginx-deployment.yaml
```

**Key difference:** Imperative scaling is not reflected in your YAML file. If you run `kubectl apply -f` again after imperative scaling, the YAML's `replicas` value wins and overrides it. Always use declarative in production so Git is the source of truth.

**Scale down behavior:** When scaling down, Kubernetes gracefully terminates extra pods by sending `SIGTERM` and waiting up to 30 seconds (`terminationGracePeriodSeconds`) before force-killing.

---

## Rolling Updates and Rollbacks

### Trigger a rolling update
```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.25 -n dev
```

### Watch the rollout
```bash
kubectl rollout status deployment/nginx-deployment -n dev
```

Kubernetes replaces pods **one by one** — it never terminates an old pod until a new one is healthy. This guarantees **zero downtime** during updates.

### View rollout history
```bash
kubectl rollout history deployment/nginx-deployment -n dev
```

```
REVISION  CHANGE-CAUSE
1         <none>        ← nginx:1.24 (original)
2         <none>        ← nginx:1.25 (updated)
```

> Use `--record` flag with `kubectl set image` to capture the command as CHANGE-CAUSE for better audit history.

### Rollback
```bash
kubectl rollout undo deployment/nginx-deployment -n dev
```

**Key insight:** A rollback is not "going back" — it creates a **new revision** (Revision 3) with the same spec as the previous version. Revision numbers always increase. This is why after undo, history shows:

```
REVISION  CHANGE-CAUSE
2         <none>        ← nginx:1.25
3         <none>        ← nginx:1.24 (same as Rev 1 was)
```

Verify the image after rollback:
```bash
kubectl describe deployment nginx-deployment -n dev | grep Image
```

---

## Clean Up

```bash
kubectl delete deployment nginx-deployment -n dev
kubectl delete pod nginx-dev -n dev
kubectl delete pod nginx-staging -n staging
kubectl delete namespace dev staging production
```

> **Warning:** Deleting a namespace removes **everything inside it** — all pods, deployments, services, configmaps, etc. Be extremely careful with this in production.

---

## Summary

| Concept | Key Takeaway |
|---|---|
| Namespaces | Virtual isolation within a cluster — use `-n` or `-A` to target them |
| Deployment | Manages pods via a ReplicaSet + control loop = self-healing |
| replicas | Desired state — the control loop enforces this count at all times |
| selector.matchLabels | Must match template.metadata.labels — this is how the Deployment finds its pods |
| Rolling update | Pods replaced one by one with zero downtime |
| Rollback | Creates a new forward revision with the old spec — history never decreases |

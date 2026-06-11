# Lab 15: GKE Network Policies — Pod-to-Pod Traffic Isolation

**Exam Domain:** Advanced — Kubernetes Security

---

## Overview

By default, all Pods in a Kubernetes cluster can communicate with each other. Network Policies are firewall rules for Pods — they restrict which Pods can talk to which other Pods, based on labels and namespaces.

### Key Concepts
- **NetworkPolicy** — A Kubernetes resource that controls ingress and/or egress traffic to Pods.
- **Default Deny** — A NetworkPolicy with an empty `podSelector` and no rules blocks all traffic to pods in that namespace. This is the recommended starting point.
- **Label Selectors** — Policies target pods using `podSelector` and allow traffic from specific sources using `namespaceSelector` and `podSelector` in `from`/`to` rules.
- **GKE Dataplane V2** — GKE's modern network dataplane (powered by eBPF/Cilium). Automatically enforces NetworkPolicies without needing `--enable-network-policy` flag.
- **Calico** — The legacy GKE network policy engine. Enabled with `--enable-network-policy` on GKE Standard.

---

## 🛡️ Hands-on Tasks

### Task 1: Create GKE Cluster with Network Policy Support

```bash
# Create cluster with network policy enabled
gcloud container clusters create ace-netpol-cluster \
    --zone=us-east1-b \
    --num-nodes=2 \
    --enable-network-policy \
    --enable-ip-alias

# Get credentials
gcloud container clusters get-credentials ace-netpol-cluster \
    --zone=us-east1-b
```

### Task 2: Deploy Test Workloads

```bash
# Create namespaces
kubectl create namespace frontend
kubectl create namespace backend

# Label namespaces (used by network policies)
kubectl label namespace frontend tier=frontend
kubectl label namespace backend tier=backend

# Deploy pods
kubectl run frontend-app --image=nginx:alpine -n frontend -l app=frontend
kubectl run backend-api --image=nginx:alpine -n backend -l app=backend
kubectl run backend-db --image=nginx:alpine -n backend -l app=database

# Wait for pods to be ready
kubectl wait --for=condition=Ready pod/frontend-app -n frontend --timeout=60s
kubectl wait --for=condition=Ready pod/backend-api -n backend --timeout=60s
kubectl wait --for=condition=Ready pod/backend-db -n backend --timeout=60s
```

### Task 3: Verify Open Communication (Before Policies)

```bash
# Get backend-api Pod IP
API_IP=$(kubectl get pod backend-api -n backend -o jsonpath='{.status.podIP}')

# This should SUCCEED — frontend can reach backend (no policy yet)
kubectl exec frontend-app -n frontend -- wget -qO- --timeout=3 http://$API_IP

# This should also SUCCEED — db can reach api (same namespace, no restrictions)
kubectl exec backend-db -n backend -- wget -qO- --timeout=3 http://$API_IP
```

### Task 4: Apply Default Deny-All Policy

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# NOW both should FAIL (all ingress to backend is blocked)
kubectl exec frontend-app -n frontend -- wget -qO- --timeout=3 http://$API_IP
# Expected: wget: download timed out

kubectl exec backend-db -n backend -- wget -qO- --timeout=3 http://$API_IP
# Expected: wget: download timed out
```

### Task 5: Allow Only Frontend → Backend API

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: frontend
      podSelector:
        matchLabels:
          app: frontend
  policyTypes:
  - Ingress
EOF

# Frontend → backend-api should now SUCCEED
kubectl exec frontend-app -n frontend -- wget -qO- --timeout=3 http://$API_IP

# Backend-db → backend-api should still FAIL
kubectl exec backend-db -n backend -- wget -qO- --timeout=3 http://$API_IP
```

### Task 6: Add Egress Policy (Restrict Outbound)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-db-egress
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: database
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - port: 80
      protocol: TCP
  - to:   # Allow DNS resolution
    - namespaceSelector: {}
    ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
  policyTypes:
  - Egress
EOF
```

---

## ✅ Verification

```bash
# List network policies
kubectl get networkpolicies -n backend

# Describe a policy
kubectl describe networkpolicy allow-frontend-to-api -n backend

# Summary test matrix:
# frontend-app → backend-api: ✅ ALLOWED
# backend-db   → backend-api: ❌ DENIED (deny-all + no matching allow rule)
# backend-db   → external:    ❌ DENIED (egress policy restricts)
```

---

## 🧹 Cleanup

```bash
kubectl delete namespace frontend backend
gcloud container clusters delete ace-netpol-cluster --zone=us-east1-b --quiet
```

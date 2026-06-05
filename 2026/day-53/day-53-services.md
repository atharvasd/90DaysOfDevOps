# Day 53 – Kubernetes Services

## What Problem Do Services Solve?

Every Pod gets its own IP address, but there are two problems:
1. **Pod IPs are not stable** — when a Pod restarts or gets replaced, it gets a new IP
2. **A Deployment runs multiple Pods** — which Pod IP do you connect to?

A Service solves both by providing:
- A **stable IP and DNS name** that never changes, even if Pods restart
- **Load balancing** across all Pods that match its selector

```
[Client] --> [Service (stable IP + DNS)] --> [Pod 1]  10.244.0.35
                                         --> [Pod 2]  10.244.0.36
                                         --> [Pod 3]  10.244.0.37
```

---

## The Application Deployment

Before creating Services, I deployed a 3-replica nginx app that all three Services point to:

```yaml
# app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

```
NAME                       READY   STATUS    IP
web-app-6cffb4b956-5t66f   1/1     Running   10.244.0.35
web-app-6cffb4b956-9cwb8   1/1     Running   10.244.0.37
web-app-6cffb4b956-pxk6v   1/1     Running   10.244.0.36
```

These 3 individual Pod IPs are exactly what Services abstract away.

---

## Service Type 1: ClusterIP (Internal Access Only)

ClusterIP is the **default** Service type. It gives Pods a stable internal IP that is only reachable from within the cluster.

```yaml
# cluster-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app-clusterip
spec:
  type: ClusterIP
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
```

Key fields:
- `selector.app: web-app` — routes traffic to all Pods with this label
- `port: 80` — the port the Service listens on
- `targetPort: 80` — the port on the Pod to forward traffic to

### Testing ClusterIP

ClusterIP is **only reachable from inside the cluster**. I ran a temporary busybox pod to test it:

```bash
kubectl run test-client --image=busybox:latest --rm -it --restart=Never -- sh
# Inside the pod:
wget -qO- http://web-app-clusterip
```

The nginx welcome page was returned — the Service successfully load-balanced the request to one of the 3 Pods.

### Real-world use
Internal service-to-service communication. For example, a backend API calling a database Service. End users never hit ClusterIP directly.

---

## Service Type 2: NodePort (External Access via Node)

NodePort builds on ClusterIP by **opening a port on every node** in the cluster. This lets you access the Service from outside the cluster.

```yaml
# nodeport-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app-nodeport
spec:
  type: NodePort
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

- `nodePort: 30080` — the port opened on every node (must be in range 30000-32767)
- Traffic flow: `<NodeIP>:30080` → Service → Pod:80

### Testing NodePort on kind

On kind, the node is a Docker container, not a real machine. So I accessed the NodePort via `docker exec`:

```bash
docker exec devops-cluster-control-plane curl -s localhost:30080
```

This returned the nginx welcome page, confirming NodePort access works.

### Real-world use
Quick testing during development. Not ideal for production because it requires knowing the node's IP and uses a non-standard high port.

---

## Service Type 3: LoadBalancer (Cloud External Access)

LoadBalancer builds on NodePort by provisioning a **cloud load balancer** in front of the nodes. In a cloud environment (GKE, EKS, AKS), this creates a real external IP or hostname.

```yaml
# loadbalancer-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
```

### Describe output

```
Name:                     web-app-loadbalancer
Type:                     LoadBalancer
IP:                       10.96.25.148      ← ClusterIP (auto-assigned)
Port:                     80/TCP
NodePort:                 31917/TCP         ← NodePort (auto-assigned)
Endpoints:                10.244.0.36:80,10.244.0.35:80,10.244.0.37:80
```

This proves the hierarchy — a LoadBalancer service **includes** a ClusterIP and a NodePort automatically.

On my local kind cluster, `EXTERNAL-IP` stays `<pending>` because there is no cloud provider to assign a real IP. On GKE this would provision a GCP Network Load Balancer with a public IP.

### Real-world use
Production internet-facing traffic. This is the standard way to expose an application publicly in Kubernetes.

---

## Service Discovery with DNS (Task 3)

Kubernetes has a built-in DNS server (CoreDNS). Every Service gets a DNS entry automatically in the format:

```
<service-name>.<namespace>.svc.cluster.local
```

Tested with:
```bash
kubectl run dns-test --image=busybox:latest --rm -it --restart=Never -- sh
# Inside the pod:
nslookup web-app-clusterip
```

Output:
```
Name:   web-app-clusterip.default.svc.cluster.local
Address: 10.96.17.163
```

The DNS resolved correctly to the ClusterIP. The short name (`web-app-clusterip`) works within the same namespace. Use the full name (`web-app-clusterip.default.svc.cluster.local`) when calling across namespaces.

---

## What Are Endpoints?

When a Service routes traffic to Pods, Kubernetes creates an **Endpoints** object behind the scenes. It tracks the actual IP:port of every healthy Pod matching the Service's selector.

```bash
kubectl get endpoints web-app-clusterip
# NAME                ENDPOINTS                                      AGE
# web-app-clusterip   10.244.0.35:80,10.244.0.36:80,10.244.0.37:80  80m
```

If a Pod restarts and gets a new IP, the Endpoints object is updated automatically. The Service IP stays the same — that's the whole point.

---

## All Three Services Side by Side

```
NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        SELECTOR
web-app-clusterip      ClusterIP      10.96.17.163   <none>        80/TCP         app=web-app
web-app-nodeport       NodePort       10.96.58.181   <none>        80:30080/TCP   app=web-app
web-app-loadbalancer   LoadBalancer   10.96.25.148   <pending>     80:31917/TCP   app=web-app
```

The port mapping format `80:30080` means `ServicePort:NodePort` — only shown for NodePort and LoadBalancer since ClusterIP has no NodePort.

---

## Service Types Summary

| Type | Reachable From | Port | Use Case |
|------|---------------|------|----------|
| ClusterIP | Inside cluster only | Service port (80) | Internal microservice communication |
| NodePort | Node IP + high port | 30000-32767 | Dev/testing, direct node access |
| LoadBalancer | Public internet | Standard port (80/443) | Production traffic via cloud LB |

### The Hierarchy

```
LoadBalancer
  └── NodePort        (opens port on every node)
        └── ClusterIP (stable internal IP + DNS)
              └── Endpoints (actual Pod IPs)
```

Each type **builds on** the previous one. A LoadBalancer service automatically has a ClusterIP and a NodePort.

---

## Key kubectl Commands

```bash
kubectl get services                          # list all services
kubectl get services -o wide                  # include selector column
kubectl describe service <name>               # full config + endpoints
kubectl get endpoints <name>                  # see which pod IPs are targeted
kubectl run test --image=busybox --rm -it --restart=Never -- sh  # temp test pod
```

---

## What I Learned

- Services decouple clients from individual Pod IPs — clients talk to the Service, not the Pods
- The selector is the glue: Service selector must match Pod labels exactly, or traffic goes nowhere
- ClusterIP ⊂ NodePort ⊂ LoadBalancer — each type is a superset of the previous
- `port` ≠ `targetPort` — the Service can listen on a different port than the Pod
- CoreDNS auto-creates DNS entries for every Service — use short names within the same namespace, full names across namespaces
- On kind/local clusters, LoadBalancer `EXTERNAL-IP` is always `<pending>` — this is expected
- `kubectl get endpoints` is a great debugging tool when traffic isn't reaching pods

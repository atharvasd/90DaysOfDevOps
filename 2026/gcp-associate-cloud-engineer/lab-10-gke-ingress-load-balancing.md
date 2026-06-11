# Lab 10: GKE Ingress and GCP Load Balancing

**Exam Domain:** Advanced — External Traffic Management

---

## Overview

GKE Ingress is a Kubernetes Ingress controller that automatically provisions Google Cloud HTTP(S) Application Load Balancers. It gives you enterprise-grade load balancing with health checks, CDN, SSL certificates, and URL routing — all managed via Kubernetes manifests.

### Key Concepts
- **GKE Ingress Controller** — Watches for Kubernetes Ingress resources and creates GCP Load Balancers.
- **`ingressClassName: "gce"`** — Tells GKE to create an external Application Load Balancer. Use `"gce-internal"` for internal.
- **BackendConfig** — GKE-specific CRD for configuring health checks, Cloud CDN, timeouts, and connection draining.
- **FrontendConfig** — GKE-specific CRD for HTTPS redirects and SSL policy.
- **Container-Native Load Balancing (NEGs)** — Routes traffic directly to Pods (skipping iptables). Requires VPC-native clusters.

> ⚠️ **Deprecated:** The annotation `kubernetes.io/ingress.class` is deprecated. Use `spec.ingressClassName` instead.

---

## 🔀 Hands-on Tasks

### Task 1: Configure BackendConfig for Health Checks and CDN

```yaml
# k8s/backend-config.yaml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: app-backend-config
  namespace: default
spec:
  healthCheck:
    checkIntervalSec: 15
    port: 8080
    type: HTTP
    requestPath: /healthz
  cdn:
    enabled: true
    cachePolicy:
      includeHost: true
      includeProtocol: true
  connectionDraining:
    drainingTimeoutSec: 60
  timeoutSec: 30
```

```bash
kubectl apply -f k8s/backend-config.yaml
```

### Task 2: Deploy Application and Service with BackendConfig

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
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
      - name: app
        image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
---
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
  namespace: default
  annotations:
    cloud.google.com/backend-config: '{"default": "app-backend-config"}'
    cloud.google.com/neg: '{"ingress": true}'
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
  selector:
    app: web-app
```

```bash
kubectl apply -f k8s/deployment.yaml
```

### Task 3: Create GKE Ingress (Provisions GCP Load Balancer)

```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-app-ingress
  namespace: default
spec:
  ingressClassName: "gce"
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app-service
            port:
              number: 8080
```

```bash
kubectl apply -f k8s/ingress.yaml
```

### Task 4: Configure FrontendConfig for HTTPS Redirect

```yaml
# k8s/frontend-config.yaml
apiVersion: networking.gke.io/v1beta1
kind: FrontendConfig
metadata:
  name: app-frontend-config
  namespace: default
spec:
  redirectToHttps:
    enabled: true
    responseCodeName: MOVED_PERMANENTLY_DEFAULT
```

Update the Ingress to use FrontendConfig:
```yaml
# Add annotation to ingress
metadata:
  annotations:
    networking.gke.io/v1beta1.FrontendConfig: "app-frontend-config"
```

### Task 5: Watch Load Balancer Provisioning

```bash
# Watch for the external IP (takes 3-5 minutes)
kubectl get ingress web-app-ingress -w

# Once IP is assigned, test it
INGRESS_IP=$(kubectl get ingress web-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$INGRESS_IP

# Check backend health in GCP
gcloud compute backend-services list
gcloud compute backend-services get-health <BACKEND_SERVICE_NAME> --global
```

---

## ✅ Verification

```bash
# Verify Ingress status
kubectl describe ingress web-app-ingress

# Verify GCP Load Balancer was created
gcloud compute forwarding-rules list
gcloud compute url-maps list

# Test the application
curl -I http://$INGRESS_IP
```

---

## 🧹 Cleanup

```bash
kubectl delete ingress web-app-ingress
kubectl delete service web-app-service
kubectl delete deployment web-app
kubectl delete backendconfig app-backend-config
kubectl delete frontendconfig app-frontend-config
```

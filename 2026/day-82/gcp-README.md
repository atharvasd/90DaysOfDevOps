# Day 82 -- GKE Networking with Gateway API and Persistent Storage

## Task
Your GKE cluster is running and the AI-BankApp deployed with raw manifests. But production needs proper ingress, HTTPS, session persistence, and reliable storage. The AI-BankApp project uses the Kubernetes Gateway API with Envoy Gateway instead of traditional Ingress -- the next generation of Kubernetes traffic management.

Today you set up the Gateway API on GKE, configure TLS with cert-manager, understand GCP Persistent Disk storage in action, and explore the AI-BankApp's production networking setup.

---

## Expected Output
- Envoy Gateway installed on GKE
- Gateway API resources (GatewayClass, Gateway, HTTPRoute) configured
- cert-manager installed with Let's Encrypt ClusterIssuer
- GCP Persistent Disk storage working for MySQL and Ollama
- Understanding of session persistence for stateful web apps
- A markdown file: `day-82-gke-networking-storage.md`

---

## Challenge Tasks

### Task 1: Understand Gateway API vs Ingress
The AI-BankApp uses the Gateway API instead of the traditional Ingress resource. 

| Feature | Ingress | Gateway API |
|---------|---------|-------------|
| API maturity | Stable but limited | GA since Kubernetes 1.26 |
| Traffic splitting | Not supported | Built-in (weighted backends) |
| Header matching | Annotation-dependent | Native HTTPRoute rules |
| Role separation | Single resource | GatewayClass (infra) -> Gateway (ops) -> HTTPRoute (dev) |
| TLS management | Annotation-based | Native TLS config in Gateway listeners |
| Session affinity | Not standardized | BackendTrafficPolicy (with Envoy) |

**GKE-specific options:**
GKE offers two main ways to use the Gateway API:
1. **GKE Gateway Controller (Native)** -- Google Cloud's native implementation. It provisions a Google Cloud HTTP(S) Load Balancer (external or internal) directly outside the cluster.
2. **Envoy Gateway (Self-hosted)** -- Runs inside your cluster as an Envoy proxy deployment and uses a GCP TCP Network Load Balancer (NLB) to ingest external traffic. This is what the AI-BankApp project uses.

---

### Task 2: Install Envoy Gateway on GKE
Envoy Gateway is the Gateway API implementation the AI-BankApp uses.

Install via Helm:
```bash
helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --version v1.4.0 \
  -n envoy-gateway-system --create-namespace \
  --wait
```

Verify the installation:
```bash
kubectl get pods -n envoy-gateway-system
kubectl get gatewayclass
```

You should see the `envoy-gateway` GatewayClass registered. If Gateway API CRDs are missing in GKE, apply the standard manifest:
```bash
kubectl get crd gateways.gateway.networking.k8s.io 2>/dev/null || \
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```

---

### Task 3: Deploy the AI-BankApp with Gateway API
Deploy the core manifests if they aren't already running:
```bash
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/pv.yml
kubectl apply -f k8s/pvc.yml
kubectl apply -f k8s/configmap.yml
kubectl apply -f k8s/secrets.yml
kubectl apply -f k8s/mysql-deployment.yml
kubectl apply -f k8s/service.yml
kubectl apply -f k8s/ollama-deployment.yml
kubectl apply -f k8s/bankapp-deployment.yml
kubectl apply -f k8s/hpa.yml
```

Apply the Gateway configuration (`k8s/gateway.yml`):
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: bankapp-gateway
  namespace: bankapp
spec:
  gatewayClassName: envoy-gateway
  listeners:
    - name: http
      protocol: HTTP
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: bankapp-route
  namespace: bankapp
spec:
  parentRefs:
    - name: bankapp-gateway
      sectionName: http
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: bankapp-service
          port: 8080
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: bankapp-session
  namespace: bankapp
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: bankapp-route
  loadBalancer:
    type: ConsistentHash
    consistentHash:
      type: Cookie
      cookie:
        name: BANKAPP_AFFINITY
        ttl: 3600s
```

Apply the Gateway:
```bash
kubectl apply -f k8s/gateway.yml
```

GCP will provision a TCP Load Balancer forwarding traffic to your Envoy proxy pods. Wait for the external IP to appear:
```bash
kubectl get gateway bankapp-gateway -n bankapp -w
```

Retrieve the IP:
```bash
export GATEWAY_IP=$(kubectl get gateway bankapp-gateway -n bankapp -o jsonpath='{.status.addresses[0].value}')
echo "App IP: $GATEWAY_IP"
curl -I http://$GATEWAY_IP
```

---

### Task 4: Set Up TLS with cert-manager
Install cert-manager using Helm:
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set crds.enabled=true \
  --wait
```

Verify that cert-manager is running:
```bash
kubectl get pods -n cert-manager
```

Apply the ACME ClusterIssuer:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-account-key
    solvers:
      - http01:
          gatewayHTTPRoute:
            parentRefs:
              - group: gateway.networking.k8s.io
                kind: Gateway
                name: bankapp-gateway
                namespace: bankapp
```

Use `nip.io` to map a wildcard domain name to your external IP address:
```bash
export HOSTNAME="${GATEWAY_IP}.nip.io"
echo "HTTPS URL: https://$HOSTNAME"
```

Update your gateway configuration to use the HTTPS listener with TLS enabled, point the hostname to `$HOSTNAME`, and verify that the TLS certificate is issued automatically.

---

### Task 5: Understand GCP Persistent Disk Storage in Action
The AI-BankApp uses GKE's default Compute Engine Persistent Disk CSI driver. GKE clusters natively provide standard storage classes.

Check GKE storage classes:
```bash
kubectl get storageclass
```
You should see:
- `standard-rwo` (backed by `pd-balanced` or `pd-standard` Persistent Disks).

Verify PVCs are bound:
```bash
kubectl get pvc -n bankapp
```

Find the real disks created in GCP:
```bash
gcloud compute disks list \
  --filter="labels.kubernetes-io-created-for-pvc-name:*" \
  --format="table(name,sizeGb,type,status)"
```

**Test persistence:**
1. Connect to MySQL and check current database metadata:
```bash
kubectl exec -n bankapp deploy/mysql -- mysql -uroot -pTest@123 -e "SHOW DATABASES;"
```
2. Force delete the MySQL pod:
```bash
kubectl delete pod -n bankapp -l app=mysql
```
3. Wait for the pod to restart and verify data:
```bash
kubectl exec -n bankapp deploy/mysql -- mysql -uroot -pTest@123 -e "SHOW DATABASES;"
```
The storage persists because GKE automatically detaches the persistent disk from the old worker node and re-attaches it to the new node where the pod starts up.

---

### Task 6: Explore HPA and Node Capacity
The Horizontal Pod Autoscaler (HPA) monitors CPU and automatically scales the BankApp pods based on traffic.

Verify the status of the HPA:
```bash
kubectl get hpa -n bankapp
```

Check resource utilization across GKE nodes:
```bash
kubectl top nodes
kubectl top pods -n bankapp
```

Clean up the workload to preserve your cluster for the capstone:
```bash
kubectl delete -f k8s/gateway.yml
kubectl delete -f k8s/hpa.yml
kubectl delete -f k8s/bankapp-deployment.yml
kubectl delete -f k8s/ollama-deployment.yml
kubectl delete -f k8s/mysql-deployment.yml
kubectl delete -f k8s/service.yml
kubectl delete -f k8s/secrets.yml
kubectl delete -f k8s/configmap.yml
kubectl delete -f k8s/pvc.yml
kubectl delete -f k8s/pv.yml
kubectl delete -f k8s/namespace.yml
```

---

## Hints
- Under GKE, the native storage class is `standard-rwo`. The volume provisioner is `pd.csi.storage.gke.io`.
- GCP Persistent Disks are regional or zonal. Standard disks are zonal. If a Pod is scheduled to a different zone than where the Persistent Disk was created, it won't be able to mount it. GKE's default scheduling handles zone-locking natively if node pools span zones.
- Wildcard DNS services like `nip.io` make testing HTTPS endpoints extremely easy without purchasing domains.

---

## Documentation
Create `day-82-gke-networking-storage.md` with:
- Gateway API architecture diagram.
- Comparison table of Gateway API vs Ingress.
- Key GKE-specific Gateway components.
- Verification of session affinity using cookies.
- Screenshots of `kubectl get gateway` with the external IP.
- GCP Persistent Disk lifecycle explanation: StorageClass -> PVC -> PV -> Compute Disk.
- Screenshots of `kubectl get pvc`.

---

## Submission
1. Add `day-82-gke-networking-storage.md` to `2026/day-82/`
2. Commit and push to your fork.

---

## Learn in Public
Share on LinkedIn: "Learned about GKE Advanced Networking today -- implemented Gateway API with Envoy proxy, configured cookie-based session persistence, and enabled dynamic storage provisioning using GCP's Persistent Disk CSI driver. Kubernetes storage and load balancing are beautiful."

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`

Happy Learning!
**TrainWithShubham**

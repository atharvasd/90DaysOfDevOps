# Day 83 -- GKE Project: Production Deployment of AI-BankApp

## Task
Three days of GKE -- cluster provisioning with Terraform, Gateway API networking, GCP Persistent Disks, and TLS. Today you put it all together and deploy the AI-BankApp as a production-grade application on GKE. Full stack: Spring Boot app with MySQL and Ollama AI, persistent storage, autoscaling, monitoring, and complete end-to-end validation.

This is the kind of deployment you would do on the job.

---

## Expected Output
- Complete AI-BankApp stack deployed on GKE
- MySQL with persistent GCP storage, Ollama with model loaded
- Gateway API routing traffic, HPA scaling pods
- Monitoring stack (Prometheus + Grafana) observing the cluster
- Full end-to-end validation checklist passed
- Complete teardown of all Google Cloud resources
- A markdown file: `day-83-gke-project.md`

---

## Challenge Tasks

### Task 1: Deploy the Complete AI-BankApp Stack
Make sure your GKE cluster is running:
```bash
kubectl get nodes
```

If you destroyed the cluster, re-provision it:
```bash
cd terraform
terraform apply
gcloud components install gke-gcloud-auth-plugin 2>/dev/null || echo "Auth plugin check"
gcloud container clusters get-credentials bankapp-gke --region us-central1
```

Deploy the entire application stack in order:
```bash
cd ..

# 1. Namespace and storage
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/pv.yml
kubectl apply -f k8s/pvc.yml

# 2. Configuration
kubectl apply -f k8s/configmap.yml
kubectl apply -f k8s/secrets.yml

# 3. Database and AI service
kubectl apply -f k8s/mysql-deployment.yml
kubectl apply -f k8s/service.yml
kubectl apply -f k8s/ollama-deployment.yml

# 4. Wait for dependencies
echo "Waiting for MySQL..."
kubectl wait --for=condition=ready pod -l app=mysql -n bankapp --timeout=120s

echo "Waiting for Ollama (pulling model can take 2-5 minutes)..."
kubectl wait --for=condition=ready pod -l app=ollama -n bankapp --timeout=600s

# 5. Application
kubectl apply -f k8s/bankapp-deployment.yml
kubectl apply -f k8s/hpa.yml

# 6. Wait for BankApp
echo "Waiting for BankApp..."
kubectl wait --for=condition=ready pod -l app=bankapp -n bankapp --timeout=300s
```

Verify everything is running:
```bash
kubectl get all -n bankapp
kubectl get pvc -n bankapp
```

You should see:
- MySQL: 1 pod running with 5Gi PVC bound
- Ollama: 1 pod running with 10Gi PVC bound
- BankApp: 2-4 pods running (managed by HPA)
- Services: 3 ClusterIP services

---

### Task 2: Set Up Gateway API and Access the App
Install Envoy Gateway (if not done on Day 82):
```bash
helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --version v1.4.0 \
  -n envoy-gateway-system --create-namespace \
  --wait 2>/dev/null || echo "Already installed"
```

Apply the Gateway configuration:
```bash
kubectl apply -f k8s/gateway.yml
```

Wait for the GCP TCP Load Balancer to provision:
```bash
kubectl get gateway -n bankapp -w
```

Get the external IP address:
```bash
export APP_URL=$(kubectl get gateway bankapp-gateway -n bankapp -o jsonpath='{.status.addresses[0].value}')
echo "AI-BankApp URL: http://$APP_URL"
```

Test the application:
```bash
# Health check (Spring Boot Actuator)
curl -s http://$APP_URL/actuator/health | python3 -m json.tool

# Load the home page
curl -s -o /dev/null -w "%{http_code}" http://$APP_URL
```

Open `http://$APP_URL` in your browser:
1. Click "Register" and create an account
2. Log in with your credentials
3. Perform banking operations (deposit, withdraw, transfer)
4. Try the AI chatbot -- ask a financial question
5. Toggle dark/light mode

---

### Task 3: Deploy the Monitoring Stack
Deploy Prometheus and Grafana to monitor the AI-BankApp on GKE.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=3d \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --wait --timeout 600s
```

Access Grafana via port-forwarding:
```bash
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```
Open `http://localhost:3000`. Login: `admin` / `admin123`.

Create a ServiceMonitor to scrape the BankApp metrics:
```yaml
# bankapp-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: bankapp-monitor
  namespace: monitoring
  labels:
    release: monitoring
spec:
  namespaceSelector:
    matchNames:
      - bankapp
  selector:
    matchLabels:
      app: bankapp
  endpoints:
    - port: "8080"
      path: /actuator/prometheus
      interval: 15s
```

```bash
kubectl apply -f bankapp-servicemonitor.yaml
```

Query AI-BankApp metrics in Grafana or Prometheus:
- JVM memory usage: `jvm_memory_used_bytes{namespace="bankapp"}`
- HTTP request rate: `rate(http_server_requests_seconds_count{namespace="bankapp"}[5m])`
- HTTP request latency (95th percentile): `histogram_quantile(0.95, rate(http_server_requests_seconds_bucket{namespace="bankapp"}[5m]))`

---

### Task 4: End-to-End Validation Checklist
Run through the complete validation:

**Application layer:**
- All pods running and ready: `kubectl get pods -n bankapp`
- App responds on health endpoint: `curl -s http://$APP_URL/actuator/health`
- HPA is active: `kubectl get hpa -n bankapp`
- Prometheus metrics endpoint works: `curl -s http://$APP_URL/actuator/prometheus | head -10`

**Data layer:**
- MySQL is healthy: `kubectl exec -n bankapp deploy/mysql -- mysqladmin ping -h localhost -uroot -pTest@123`
- PVCs are bound to GKE Persistent Disks: `kubectl get pvc -n bankapp`
- Ollama has the model loaded: `kubectl exec -n bankapp deploy/ollama -- ollama list`

**Infrastructure layer:**
- Nodes are healthy: `kubectl get nodes` and `kubectl top nodes`
- Gateway is serving traffic: `kubectl get gateway -n bankapp`
- Monitoring is running: `kubectl get pods -n monitoring | head -5`

**Security layer:**
- BankApp runs as non-root (devsecops user): `kubectl exec -n bankapp deploy/bankapp -- whoami`
- Secrets are not exposed in environment: `kubectl get secret bankapp-secret -n bankapp -o yaml | grep -c "MYSQL_ROOT_PASSWORD"`

---

### Task 5: Reflect on the Full GKE Journey
Map each concept to the day you learned it:

| Day | What You Built | AI-BankApp Connection |
|-----|---------------|----------------------|
| 81 | GKE cluster via Terraform, kubectl credentials, manual deploy | Used the project's GCP Terraform configs to provision GKE |
| 82 | Gateway API, Envoy, GCP Persistent Disks, session persistence | Used `k8s/gateway.yml`, `k8s/pv.yml`, and cert-manager |
| 83 | Full production deployment, monitoring, validation | Complete stack: app + DB + AI + networking + observability |

**What GKE provides that you have now seen:**
- Terraform-provisioned global VPC with regional subnets and alias IP ranges.
- Managed node pool with auto-healing and auto-scaling.
- Native GKE storage integration utilizing Compute Engine Persistent Disks.
- Gateway API with Envoy for traffic routing.
- Session persistence for Spring Security.
- HPA scaling policies based on metrics.

**What you would add for a real production deployment on GCP:**
- Cloud DNS with ExternalDNS.
- Cloud NAT to prevent worker nodes from having public IP addresses.
- GKE Workload Identity instead of static keys.
- Cloud SQL for MySQL (fully managed database) instead of a self-managed DB pod.
- Google Cloud Armor for DDoS and WAF security at the Load Balancer level.

---

### Task 6: Complete Teardown
**This is critical -- do not leave resources running in GCP.**

Delete workloads first:
```bash
# Delete monitoring
helm uninstall monitoring -n monitoring

# Delete Gateway resources (releases the TCP Load Balancer)
kubectl delete -f k8s/gateway.yml 2>/dev/null

# Delete the BankApp stack
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

# Delete Envoy Gateway
helm uninstall envoy-gateway -n envoy-gateway-system 2>/dev/null

# Delete cert-manager
helm uninstall cert-manager -n cert-manager 2>/dev/null

# Delete namespaces
kubectl delete namespace monitoring envoy-gateway-system cert-manager 2>/dev/null
```

Verify that all LoadBalancers and Persistent Disks are deleted:
```bash
kubectl get svc -A | grep LoadBalancer
kubectl get pvc -A
```

Destroy the GKE infrastructure:
```bash
cd terraform
terraform destroy
```

---

## Hints
- `kubectl wait` is the best way to script dependencies in CI/CD pipeline tests.
- Helm releases can sometimes fail to delete cleanly if CRDs are removed before releases. Uninstall the charts in the correct order.
- To check for lingering disks in GCP: `gcloud compute disks list`. If any remain, delete them manually to avoid extra charges.

---

## Documentation
Create `day-83-gke-project.md` with:
- Full GKE architecture diagram (VPC -> GKE -> Nodes -> Pods -> Gateway -> Load Balancer -> Internet).
- Screenshot of the AI-BankApp dashboard and financial AI chatbot running.
- Screenshot of `kubectl get all -n bankapp`.
- Screenshot of Grafana showing CPU and Memory metrics.
- PromQL queries used.
- Complete validation checklist.
- Teardown confirmation.

---

## Submission
1. Add `day-83-gke-project.md` to `2026/day-83/`
2. Commit and push to your fork.

---

## Learn in Public
Share on LinkedIn: "Completed the GKE Block! Deployed the production-grade AI-BankApp on Google Kubernetes Engine (GKE) with Envoy Gateway, GCP Persistent Disks, HPA, and Prometheus/Grafana monitoring. Ready to scale on Google Cloud!"

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`

Happy Learning!
**TrainWithShubham**

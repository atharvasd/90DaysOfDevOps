# Lab 04: Serverless Deployments — Cloud Run and Cloud Functions (2nd Gen)

**Exam Domain:** 3 — Deploying and implementing a cloud solution

---

## Overview

Google Cloud offers two primary serverless compute options. Both scale to zero and charge only for actual usage.

### Key Concepts
- **Cloud Run** — Runs any container. Supports HTTP, gRPC, and WebSockets. Based on Knative. Best for web apps, APIs, and microservices.
- **Cloud Functions (2nd Gen)** — Runs individual functions triggered by events. Built on Cloud Run + Eventarc under the hood. Best for glue code, event processing, and lightweight automation.
- **Artifact Registry** — Google's managed container/package registry. Replaces the deprecated Container Registry (gcr.io).
- **Traffic Splitting** — Cloud Run lets you route a percentage of traffic to different revisions for canary deployments.

> ⚠️ **Important:** Always use **Cloud Functions 2nd Gen** (`--gen2`). 1st Gen is legacy.

---

## ☁️ Hands-on Tasks

### Task 1: Set up Artifact Registry

```bash
# Create docker repository (replaces deprecated Container Registry)
gcloud artifacts repositories create ace-docker-repo \
    --repository-format=docker \
    --location=us-east1 \
    --description="Docker repository for ACE certification"

# Configure Docker auth for Artifact Registry
gcloud auth configure-docker us-east1-docker.pkg.dev
```

### Task 2: Deploy to Cloud Run

```bash
# Deploy directly from a public sample image
gcloud run deploy ace-web-app \
    --image=us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0 \
    --platform=managed \
    --region=us-east1 \
    --allow-unauthenticated

# Get the service URL
gcloud run services describe ace-web-app \
    --region=us-east1 --format='value(status.url)'
```

### Task 3: Configure Traffic Splitting (Canary Deployment)

```bash
# Deploy revision 2 with --no-traffic (dark launch)
gcloud run deploy ace-web-app \
    --image=us-docker.pkg.dev/google-samples/containers/gke/hello-app:2.0 \
    --platform=managed \
    --region=us-east1 \
    --no-traffic

# Allocate 10% traffic to revision 2 (canary test)
gcloud run services update-traffic ace-web-app \
    --region=us-east1 \
    --to-revisions=LATEST=10

# Check traffic split
gcloud run services describe ace-web-app \
    --region=us-east1 --format='yaml(status.traffic)'

# Promote to 100% after successful test
gcloud run services update-traffic ace-web-app \
    --region=us-east1 \
    --to-latest
```

### Task 4: Deploy a Cloud Function (2nd Gen) — HTTP Trigger

```bash
mkdir -p ace-function && cd ace-function

cat > main.py << 'EOF'
import functions_framework

@functions_framework.http
def hello(request):
    name = request.args.get("name", "World")
    return f"Hello, {name}! From Cloud Functions 2nd Gen."
EOF

cat > requirements.txt << 'EOF'
functions-framework==3.*
EOF

# Deploy as 2nd Gen function
gcloud functions deploy ace-hello-function \
    --gen2 \
    --runtime=python312 \
    --region=us-east1 \
    --source=. \
    --entry-point=hello \
    --trigger-http \
    --allow-unauthenticated
```

### Task 5: Test the Cloud Function

```bash
# Get the URL
FUNC_URL=$(gcloud functions describe ace-hello-function \
    --gen2 --region=us-east1 --format='value(serviceConfig.uri)')

curl "$FUNC_URL?name=Atharva"
# Output: Hello, Atharva! From Cloud Functions 2nd Gen.
```

### Task 6: Deploy a Pub/Sub-Triggered Cloud Function

```bash
# Create a Pub/Sub topic first
gcloud pubsub topics create ace-orders-topic

cat > main.py << 'EOF'
import functions_framework
import base64

@functions_framework.cloud_event
def process_order(cloud_event):
    data = base64.b64decode(cloud_event.data["message"]["data"]).decode()
    print(f"Processing order: {data}")
EOF

gcloud functions deploy ace-order-processor \
    --gen2 \
    --runtime=python312 \
    --region=us-east1 \
    --source=. \
    --entry-point=process_order \
    --trigger-topic=ace-orders-topic

# Test it
gcloud pubsub topics publish ace-orders-topic --message='{"orderId":"2001"}'
gcloud functions logs read ace-order-processor --gen2 --region=us-east1 --limit=5
```

---

## ✅ Verification

```bash
# Cloud Run
curl $(gcloud run services describe ace-web-app --region=us-east1 --format='value(status.url)')

# Cloud Function
curl "$FUNC_URL?name=Test"

# List all deployed functions
gcloud functions list --gen2 --region=us-east1
```

---

## 🧹 Cleanup

```bash
gcloud run services delete ace-web-app --region=us-east1 --quiet
gcloud functions delete ace-hello-function --gen2 --region=us-east1 --quiet
gcloud functions delete ace-order-processor --gen2 --region=us-east1 --quiet
gcloud pubsub topics delete ace-orders-topic --quiet
gcloud artifacts repositories delete ace-docker-repo --location=us-east1 --quiet
```

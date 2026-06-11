# Lab 09: Cloud Build Pipelines and Artifact Registry

**Exam Domain:** Advanced — CI/CD with GCP-Native Tools

---

## Overview

Cloud Build is GCP's serverless CI/CD platform. It executes build steps as containers, making it language and tool agnostic. Combined with Artifact Registry, it provides a complete container delivery pipeline.

### Key Concepts
- **`cloudbuild.yaml`** — The build configuration file. Each `step` runs in its own container.
- **Cloud Builders** — Pre-built container images for common tools (Docker, Maven, npm, gcloud, kubectl, terraform).
- **Artifact Registry** — GCP's managed container and package registry. Replaces deprecated Container Registry (gcr.io).
- **Build Triggers** — Automatically trigger builds on git push, tag, or PR events.
- **Substitution Variables** — `$PROJECT_ID`, `$COMMIT_SHA`, `$BRANCH_NAME` are automatically available in builds.

---

## 🚀 Hands-on Tasks

### Task 1: Create Artifact Registry Repository

```bash
gcloud artifacts repositories create ace-docker-repo \
    --repository-format=docker \
    --location=us-east1 \
    --description="Docker images for CI/CD pipeline"

# Configure Docker auth
gcloud auth configure-docker us-east1-docker.pkg.dev
```

### Task 2: Write a Cloud Build Configuration

```yaml
# cloudbuild.yaml
steps:
  # Step 1: Run tests
  - name: 'node:20-slim'
    entrypoint: 'npm'
    args: ['test']

  # Step 2: Build container image
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - 'us-east1-docker.pkg.dev/$PROJECT_ID/ace-docker-repo/myapp:$COMMIT_SHA'
      - '-t'
      - 'us-east1-docker.pkg.dev/$PROJECT_ID/ace-docker-repo/myapp:latest'
      - '.'

  # Step 3: Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '--all-tags'
      - 'us-east1-docker.pkg.dev/$PROJECT_ID/ace-docker-repo/myapp'

  # Step 4: Deploy to Cloud Run
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'run'
      - 'deploy'
      - 'myapp'
      - '--image=us-east1-docker.pkg.dev/$PROJECT_ID/ace-docker-repo/myapp:$COMMIT_SHA'
      - '--region=us-east1'
      - '--platform=managed'

images:
  - 'us-east1-docker.pkg.dev/$PROJECT_ID/ace-docker-repo/myapp:$COMMIT_SHA'
  - 'us-east1-docker.pkg.dev/$PROJECT_ID/ace-docker-repo/myapp:latest'

options:
  logging: CLOUD_LOGGING_ONLY
```

### Task 3: Run Cloud Build Manually

```bash
# Submit a build from current directory
gcloud builds submit --config=cloudbuild.yaml .

# Or build with a simple Dockerfile (no config file needed)
gcloud builds submit --tag=us-east1-docker.pkg.dev/$PROJECT_ID/ace-docker-repo/myapp:v1 .
```

### Task 4: Create a Build Trigger (Git-based CI/CD)

```bash
# Connect your GitHub repository first
gcloud builds triggers create github \
    --name="deploy-on-push" \
    --repo-name="my-app-repo" \
    --repo-owner="<your-github-username>" \
    --branch-pattern="^main$" \
    --build-config="cloudbuild.yaml"

# List triggers
gcloud builds triggers list

# Manually run a trigger
gcloud builds triggers run deploy-on-push --branch=main
```

### Task 5: View Build History and Logs

```bash
# List recent builds
gcloud builds list --limit=5

# Get details of a specific build
gcloud builds describe <BUILD_ID>

# Stream build logs in real-time
gcloud builds log <BUILD_ID> --stream
```

---

## ✅ Verification

```bash
# Verify image in Artifact Registry
gcloud artifacts docker images list \
    us-east1-docker.pkg.dev/ace-lab-prod-2026/ace-docker-repo

# Verify build succeeded
gcloud builds list --limit=1 --format="table(id, status, createTime)"
```

---

## 🧹 Cleanup

```bash
gcloud builds triggers delete deploy-on-push --quiet
gcloud artifacts repositories delete ace-docker-repo --location=us-east1 --quiet
```

# Lab 02: Environments and Manual Approvals

**Topic:** GitHub Actions — Deployment Gates and Protection Rules

---

## Overview

When deploying to production, you rarely want a `git push` to deploy immediately without human oversight. GitHub **Environments** allow you to pause a workflow and require manual approval before proceeding to the next job. Environments also allow you to scope secrets—so the Production DB password is only accessible to jobs explicitly running in the `production` environment.

---

## 🛠️ Hands-on Tasks

### Task 1: Create an Environment in GitHub
1. Go to your GitHub Repository -> **Settings**.
2. Click **Environments** on the left sidebar.
3. Click **New environment** and name it `production`.
4. Check the box for **Required reviewers** and add yourself (or a team) as a reviewer.
5. Under **Environment secrets**, add a secret:
   - Name: `DEPLOY_TOKEN`
   - Value: `super-secret-production-token`

### Task 2: Write a Multi-Stage Workflow

Create `.github/workflows/deploy-with-approvals.yml`:

```yaml
name: Multi-Stage Deployment

on:
  push:
    branches: [ "main" ]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - name: Run Unit Tests
        run: echo "Running tests... Passed!"

  deploy-staging:
    needs: build-and-test
    runs-on: ubuntu-latest
    # Staging does not have manual approvals configured
    environment: staging
    steps:
      - name: Deploy to Staging
        run: echo "Deploying to Staging..."

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    # Linking this job to the 'production' environment triggers the protection rules
    environment:
      name: production
      url: https://my-production-app.com
    steps:
      - name: Deploy to Production
        run: |
          echo "Deploying to Production!"
          echo "Using Secret: ${{ secrets.DEPLOY_TOKEN }}"
```

### Task 3: Trigger and Approve
1. Commit and push this file to `main`.
2. Go to the **Actions** tab in GitHub.
3. You will see the workflow run `build-and-test`, then `deploy-staging`.
4. The workflow will **pause** before `deploy-production`. It will show a yellow status indicating it is "Waiting for review".
5. Click **Review deployments**, select the production environment, leave a comment, and click **Approve and deploy**.
6. The `deploy-production` job will now execute.

---

## ✅ Best Practices
- **Scope Secrets:** Never put production secrets in Repository Secrets. Always put them in Environment Secrets. This prevents a rogue PR or branch from printing the production secrets, as they can't access the `production` environment without approval.
- **Branch Protection + Environments:** Combine branch protection rules (require PR reviews) with Environment approvals (require deployment reviews) for a robust DevSecOps pipeline.

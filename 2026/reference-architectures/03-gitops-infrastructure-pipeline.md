# Architecture 03: The GitOps Infrastructure Pipeline

**Focus:** Automation, Auditing, and Zero-Click Deployments.

---

## Overview

In modern DevSecOps, no human engineer should have `kubectl admin` or AWS `AdministratorAccess` credentials on their laptop. If an engineer gets phished, the attacker gains the keys to the entire kingdom.

This architecture delegates **all** deployment privileges to automated CI/CD and GitOps systems. Engineers push code to Git, and the systems apply the changes. 

---

## 🏗️ Architecture Diagram

```mermaid
flowchart TD
    subgraph "Git Repositories"
        AppRepo[Application Source Code<br/>(Node.js, Go)]
        InfraRepo[Infrastructure Repo<br/>(Terraform)]
        ManifestRepo[Cluster State Repo<br/>(Helm, K8s YAML, SOPS)]
    end

    subgraph "CI/CD Pipeline (GitHub Actions)"
        CI[CI Pipeline<br/>Run Tests, Build Docker Image]
        SecurityScan[Security Scanners<br/>Trivy, SonarQube]
        CD[CD Pipeline<br/>Push Image, Update Manifest Repo]
        TF[Terraform Pipeline<br/>Plan and Apply]
    end

    subgraph "Target Environment (AWS/GCP)"
        Registry[Container Registry]
        
        subgraph "Kubernetes Cluster"
            ArgoCD[ArgoCD Controller]
            App[Application Pods]
            SOPS[SOPS Decryption Controller]
        end
        
        CloudAPI[Cloud Provider API<br/>VPCs, Databases]
    end

    %% Developer Flow
    Dev((DevOps Engineer)) -- "git push" --> AppRepo
    Dev -- "git push" --> InfraRepo
    
    %% Infra Pipeline
    InfraRepo --> TF
    TF -- "Terraform Apply" --> CloudAPI
    
    %% App Pipeline
    AppRepo --> CI
    CI --> SecurityScan
    SecurityScan -- "If pass" --> CD
    CD -- "Push image tag v1.2" --> Registry
    CD -- "git commit: update tag to v1.2" --> ManifestRepo
    
    %% GitOps Pull
    ArgoCD -- "Polls every 3 minutes" --> ManifestRepo
    ArgoCD -- "Detects change, pulls YAML" --> ArgoCD
    ArgoCD -- "kubectl apply" --> App
    
    %% Secret Decryption
    SOPS -- "Decrypts Sealed Secrets" --> App
    
    %% Image Pull
    App -. "Pulls v1.2" .-> Registry
```

---

## 🔑 Key Design Decisions

### 1. Separation of Repositories
- **Application Repo:** Contains only the application source code (e.g., Python, Go) and the `Dockerfile`.
- **Infrastructure Repo:** Contains Terraform code to provision the VPCs, EKS/GKE clusters, and RDS databases.
- **Manifest Repo:** Contains ONLY Kubernetes YAML and Helm charts. It defines the *state* of the cluster.

### 2. The Push vs. Pull Model
Notice that GitHub Actions **never** touches the Kubernetes cluster. It does not run `kubectl apply`. It only runs `docker build`, pushes the image to the registry, and updates a string in the Manifest Repo (e.g., changing `image: myapp:v1.1` to `image: myapp:v1.2`). 

This is the core of GitOps: The cluster (ArgoCD) **pulls** the state from Git. This means you do not need to give GitHub Actions your Kubernetes admin credentials.

### 3. Terraform Automation
When you need a new S3 bucket or database, you write Terraform code and open a Pull Request. GitHub Actions runs `terraform plan` and posts the output as a comment on the PR. A senior engineer reviews the plan and approves the PR. Upon merging to `main`, GitHub Actions runs `terraform apply`.

### 4. Encrypted Secrets (SOPS)
Because the Manifest Repo is public (or accessible by many developers), it cannot contain plaintext Kubernetes secrets. Developers use SOPS (Secrets OPerationS) or Sealed Secrets to encrypt the YAML files before pushing. A controller inside the cluster decrypts them automatically before they are applied.

# Day 59 – Helm — Kubernetes Package Manager

## Task 1: Install Helm

### Concept
**Helm** is the package manager for Kubernetes. Instead of managing dozens of individual YAML manifests by hand, Helm compiles templates, manages releases, and installs complete pre-packaged applications (called **Charts**) into your cluster.

### Core Concepts:
- **Chart**: A package of templated Kubernetes resources (YAMLs) and a `values.yaml` file for default configs.
- **Release**: A running instance of a Chart in a Kubernetes cluster. You can install the same chart multiple times, creating separate releases.
- **Repository**: A central server hosting packaged Charts that can be shared and downloaded.

### Observation and Verification
* **Helm version installed**: [Pending user execution]

---

## Task 2: Add a Repository and Search

### Concept
Helm repositories store charts. We add repositories (such as the popular Bitnami registry) to search for pre-packaged database or web applications.
- `helm repo add` adds a source repository.
- `helm repo update` syncs local index with the remote registry.
- `helm search repo` searches local indexes for matching applications.

### Observation and Verification
* **Bitnami repository charts count**: [Pending user execution]
* **Search result for Nginx**: [Pending user execution]

---

## Task 3: Install a Chart

### Concept
We deploy a packaged chart to create a running **release**. Helm automatically creates the Deployments, Services, ConfigMaps, and permissions required by the chart templates.
- `helm install <release-name> <repo/chart>`
- `helm list` displays running releases.
- `helm get manifest <release-name>` shows the compiled raw YAML applied to K8s.

### Observation and Verification
* **Resources created by Nginx install**: [Pending user execution]
* **Default Service type created**: [Pending user execution]

---

## Task 4: Customize with Values

### Concept
A Helm Chart defines variables in a file named `values.yaml`. We override these variables to customize the release using:
1. `--set key=value` via CLI.
2. `-f custom-values.yaml` supplying a file containing overrides.

### Observation and Verification
* **Override values applied**: [Pending user execution]
* **Replicas and Service type customized**: [Pending user execution]

---

## Task 5: Upgrade and Rollback

### Concept
Helm tracks the **history** of each release. If we update configs or image tags, we run `helm upgrade`, which increments the release **revision**. If something fails, we can instantly rollback to a previous version:
- `helm upgrade`
- `helm history`
- `helm rollback <release-name> <revision-number>`

*Note: Rollback creates a new revision in the history index rather than deleting historical revisions.*

### Observation and Verification
* **Revision number before rollback**: [Pending user execution]
* **Revision number after rollback**: [Pending user execution]

---

## Task 6: Create Your Own Chart

### Concept
We can scaffold a custom chart structure using `helm create`. This builds:
- `Chart.yaml`: Metadata about the chart.
- `values.yaml`: Default configuration variables.
- `templates/`: Manifest files using Go templating syntax (`{{ .Values.key }}`).
- `charts/`: Sub-charts (dependencies).

We check syntax with `helm lint` and preview rendering using `helm template` before deploying.

### Observation and Verification
* **Custom Chart deployment status**: [Pending user execution]
* **Replicas scaled successfully**: [Pending user execution]

---

## Task 7: Clean Up
We uninstall our releases and clear our custom templates.

### Observation and Verification
* **Active releases after cleanup**: [Pending user execution]

---

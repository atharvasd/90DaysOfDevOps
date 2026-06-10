# Day 58 – Metrics Server and Horizontal Pod Autoscaler (HPA)

## Task 1: Install the Metrics Server

### Concept
The **Metrics Server** is a cluster-wide aggregator of resource usage data. It collects CPU and memory metrics from the `kubelet` summary API on each node. 
Kubernetes requires the Metrics Server for auto-scaling workloads (like HPAs) and for inspecting resource usage via the `kubectl top` command.

On local dev clusters (like Kind), we apply the Metrics Server manifest and configure the `--kubelet-insecure-tls` flag in the command args so it skips verifying the Kubelet's self-signed TLS certificate.

### Observation and Verification
* **Current Node CPU/Memory usage**: [Pending user execution]
* **Current Pods CPU/Memory usage**: [Pending user execution]

---

## Task 2: Explore kubectl top

### Concept
The command `kubectl top` displays real-time resource utilization for nodes and pods:
- `kubectl top nodes`
- `kubectl top pods -A`
- `kubectl top pods -A --sort-by=cpu`

Unlike `kubectl describe`, which shows the statically configured requests and limits, `kubectl top` queries the Metrics Server for live, active usage.

### Observation and Verification
* **Pod consuming the most CPU**: [Pending user execution]
* **Memory usage of kube-system components**: [Pending user execution]

---

## Task 3: Create a Deployment with CPU Requests

### Concept
To autoscale a Deployment, Kubernetes must know how to calculate resource utilization. The Horizontal Pod Autoscaler (HPA) uses the formula:
$$\text{Desired Replicas} = \lceil \text{Current Replicas} \times \frac{\text{Current Utilization}}{\text{Target Utilization}} \rceil$$

Utilization is calculated as a percentage of the **CPU Requests** (not the limits). If requests are missing, the HPA won't be able to calculate utilization and will report `<unknown>` status, preventing scaling.

### Observation and Verification
* **Pod CPU Requests config**: [Pending user execution]
* **Pod CPU utilization baseline**: [Pending user execution]

---

## Task 4: Create an HPA (Imperative)

### Concept
We create an HPA imperatively using the `kubectl autoscale` command, targeting a 50% CPU threshold, with a min of 1 replica and a max of 10.

### Observation and Verification
* **HPA Target status initially**: [Pending user execution]
* **HPA Replicas count**: [Pending user execution]

---

## Task 5: Generate Load and Watch Autoscaling

### Concept
We spin up a load generator pod that runs a continuous loop querying our application. As CPU usage climbs above 50% of the request value, the HPA controller calculates the desired replicas and starts scaling up the deployment.

When load is removed, the HPA will scale down, but with a **stabilization window** (by default 5 minutes) to prevent "flapping" (rapidly scaling up and down in response to transient load spikes).

### Observation and Verification
* **Peak CPU utilization percentage reached**: [Pending user execution]
* **Max replicas scaled to by HPA**: [Pending user execution]
* **Replica count after stopping load (Scale-down)**: [Pending user execution]

---

## Task 6: Create an HPA from YAML (Declarative)

### Concept
While imperative autoscaling is quick, the `autoscaling/v2` API in YAML allows configuring advanced policies under the `behavior` block. We can customize the stabilization windows and scaling speeds (policies) for both `scaleUp` and `scaleDown` directions.

### Observation and Verification
* **YAML behavior configuration details**: [Pending user execution]

---

## Task 7: Clean Up
Uninstalling the PHP deployment, service, and HPA resources.

### Observation and Verification
* **Cleanup status**: [Pending user execution]

---

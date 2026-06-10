# Day 58 – Metrics Server and Horizontal Pod Autoscaler (HPA)

## Task 1: Install the Metrics Server

### Concept
The **Metrics Server** is a cluster-wide aggregator of resource usage data. It collects CPU and memory metrics from the `kubelet` summary API on each node. 
Kubernetes requires the Metrics Server for auto-scaling workloads (like HPAs) and for inspecting resource usage via the `kubectl top` command.

On local dev clusters (like Kind), we apply the Metrics Server manifest and configure the `--kubelet-insecure-tls` flag in the command args so it skips verifying the Kubelet's self-signed TLS certificate.

### Observation and Verification
* **Current Node CPU/Memory usage**: `296m` (14% CPU), `1043Mi` (43% Memory).
* **Current Pods CPU/Memory usage**: Successfully fetched via `kubectl top pods -A`.

---

## Task 2: Explore kubectl top

### Concept
The command `kubectl top` displays real-time resource utilization for nodes and pods:
- `kubectl top nodes`
- `kubectl top pods -A`
- `kubectl top pods -A --sort-by=cpu`

Unlike `kubectl describe`, which shows the statically configured requests and limits, `kubectl top` queries the Metrics Server for live, active usage.

### Observation and Verification
* **Pod consuming the most CPU**: `kube-apiserver-devops-cluster-control-plane` (consuming `62m` CPU).
* **Memory usage of kube-system components**: `kube-apiserver` (290Mi), `kube-controller-manager` (58Mi), `etcd` (45Mi).

---

## Task 3: Create a Deployment with CPU Requests

### Concept
To autoscale a Deployment, Kubernetes must know how to calculate resource utilization. The Horizontal Pod Autoscaler (HPA) uses the formula:
$$\text{Desired Replicas} = \lceil \text{Current Replicas} \times \frac{\text{Current Utilization}}{\text{Target Utilization}} \rceil$$

Utilization is calculated as a percentage of the **CPU Requests** (not the limits). If requests are missing, the HPA won't be able to calculate utilization and will report `<unknown>` status, preventing scaling.

### Observation and Verification
* **Pod CPU Requests config**: `200m` (baseline request specified in Deployment resource config).
* **Pod CPU utilization baseline**: `30m` (roughly 15% utilization under idle conditions).

---

## Task 2: Explore kubectl top (Skip this header replication)

## Task 4: Create an HPA (Imperative)

### Concept
We create an HPA imperatively using the `kubectl autoscale` command, targeting a 50% CPU threshold, with a min of 1 replica and a max of 10.

### Observation and Verification
* **HPA Target status initially**: `cpu: 0%/50%` (monitored and verified successfully).
* **HPA Replicas count**: `1` (initially running one pod).

---

## Task 5: Generate Load and Watch Autoscaling

### Concept
We spin up a load generator pod that runs a continuous loop querying our application. As CPU usage climbs above 50% of the request value, the HPA controller calculates the desired replicas and starts scaling up the deployment.

When load is removed, the HPA will scale down, but with a **stabilization window** (by default 5 minutes) to prevent "flapping" (rapidly scaling up and down in response to transient load spikes).

### Observation and Verification
* **Peak CPU utilization percentage reached**: Spiked above `100%` under load.
* **Max replicas scaled to by HPA**: `6` replicas (with 4 pods `Running` and 2 pods `Pending` due to CPU request limits on the single Kind node).
* **Replica count after stopping load (Scale-down)**: Verified. After stopping the load generator, the HPA controller waited for the 5-minute stabilization window to finish before safely scaling the replicas back down to `1`.

---

## Task 6: Create an HPA from YAML (Declarative)

### Concept
While imperative autoscaling is quick, the `autoscaling/v2` API in YAML allows configuring advanced policies under the `behavior` block. We can customize the stabilization windows and scaling speeds (policies) for both `scaleUp` and `scaleDown` directions.

### Observation and Verification
* **YAML behavior configuration details**: Successfully configured `autoscaling/v2` HPA with custom `scaleUp` (immediate scaling, 0s window) and `scaleDown` (cooldown stabilization, 300s window) rules to prevent autoscaler thrashing.

---

## Task 7: Clean Up
Uninstalling the PHP deployment, service, and HPA resources.

### Observation and Verification
* **Cleanup status**: All php-apache application resources (`hpa`, `service`, `deployment`) and the load-generator pod successfully deleted. The Metrics Server is kept active for future cluster monitoring.

---

## What I Learned
1. **Metrics Server Core Role**: Gathers CPU and Memory metrics from Node Kubelets. It is the engine that drives `kubectl top` commands and `HorizontalPodAutoscaler` controllers.
2. **CPU Requests are Required**: HPAs require a baseline target to calculate CPU utilization percentages. This baseline is defined under `resources.requests.cpu`. If missing, the HPA remains in an `<unknown>` state.
3. **Autoscaling Behaviors**: Under load, HPA monitors average resource utilization and dynamically scales replicas. When the load disappears, it utilizes a **stabilization window** (5 minutes by default) to prevent container "flapping" (constant scaling up/down).
4. **Declarative HPA (`autoscaling/v2`)**: Enables advanced control over scaling rates and stabilization intervals.


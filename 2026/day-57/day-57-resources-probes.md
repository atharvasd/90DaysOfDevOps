# Day 57 – Resource Requests, Limits, and Probes

## Task 1: Resource Requests and Limits

### Concept
Kubernetes allows you to specify the resource requirements for your containers. 
- **Requests**: The minimum resources (CPU and memory) a container needs to run. The scheduler uses this value to decide which node to place the Pod on.
- **Limits**: The maximum resources a container is allowed to consume. Kubelet enforces these limits at runtime.

### QoS (Quality of Service) Classes
Based on your requests and limits, Kubernetes assigns one of three QoS classes to your Pod:
1. **Guaranteed**: If every container in the Pod has both CPU/memory requests and limits set, and they are exactly equal.
2. **Burstable**: If the requests are less than the limits, or if some containers don't have limits set.
3. **BestEffort**: If no requests or limits are set for any container.

### Observation and Verification
* **QoS Class of the Pod**: `Burstable` (Assigned because requests are specified and are less than limits).
* **Resource allocations in kubectl describe**: Requests: `cpu: 100m, memory: 128Mi`; Limits: `cpu: 250m, memory: 256Mi`.

---

## Task 2: OOMKilled — Exceeding Memory Limits

### Concept
CPU and Memory are managed differently when limits are exceeded:
- **CPU (Compressible)**: If a container exceeds its CPU limit, it is **throttled** (slowed down), but not killed.
- **Memory (Incompressible)**: If a container exceeds its memory limit, the system kernel's Out-Of-Memory (OOM) killer steps in and terminates the container process. 

In Kubernetes, this registers as **OOMKilled** with **Exit Code 137** (128 + signal 9 (SIGKILL)).

### Observation and Verification
* **Container exit reason**: `OOMKilled`
* **Exit code**: `137` (Indicates the container was terminated via SIGKILL by the OS kernel OOM-killer).

---

## Task 3: Pending Pod — Requesting Too Much

### Concept
If a Pod requests more CPU or memory than any single node in the cluster can provide, the scheduler cannot place the Pod. The Pod status remains **Pending** indefinitely.

### Observation and Verification
* **Pod status**: `Pending`
* **Scheduler Event message**: `0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory. Preemption is not helpful for scheduling.`

---

## Task 4: Liveness Probe

### Concept
A **Liveness Probe** determines if your application container is running and healthy. If the liveness probe fails a specified number of times (`failureThreshold`), the kubelet kills the container and restarts it according to its restart policy.

### Observation and Verification
* **Liveness Probe configuration**: `exec` running `cat /tmp/healthy` with `initialDelaySeconds: 5`, `periodSeconds: 5`, and `failureThreshold: 3`.
* **Container restarts after 30 seconds**: Yes, verified. The container successfully restarted (RESTARTS count incremented to `1`) shortly after the 30-second mark when the health file was deleted.

---

## Task 5: Readiness Probe

### Concept
A **Readiness Probe** determines if your container is ready to accept network traffic. If it fails, Kubernetes **removes the Pod's IP from the Endpoints list** of all matching Services. Unlike Liveness probes, a failed readiness probe **does not restart** the container.

### Observation and Verification
* **Initial Endpoints list**: Pod's IP (e.g. `10.244.0.X:80`) was listed under endpoints.
* **Endpoints list after probe fails**: Blank (the Pod IP was removed from `readiness-svc` endpoints).
* **Did the container restart?**: No, the pod remained `Running` with `RESTARTS: 0` because readiness failures do not trigger restarts.

---

## Task 6: Startup Probe

### Concept
A **Startup Probe** checks if the application inside the container has started up. All other probes (liveness/readiness) are disabled until the startup probe succeeds. This prevents slow-starting applications from being killed by the liveness probe before they are fully up.

### Observation and Verification
* **Startup behavior**: Successful. With `failureThreshold` set to 12 (60-second budget), the pod successfully completed its 20-second startup delay and reached `1/1 READY` with 0 restarts.
* **What happens if failureThreshold is too small?**: Setting it to 2 (10-second budget) killed the container before the 20-second startup finished, trapping the Pod in an infinite restart loop.

---

## Task 7: Clean Up
We delete all resources created for the probes and resource challenges.

### Observation and Verification
* **Cleanup status**: All pods (`resource-pod`, `stress-pod`, `pending-pod`, `liveness-pod`, `readiness-pod`, `startup-pod`) and services (`readiness-svc`) successfully deleted.

---

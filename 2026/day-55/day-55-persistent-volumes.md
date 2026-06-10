# Day 55 – Kubernetes Persistent Volumes and PVCs

## Task 1: Ephemeral Storage with emptyDir (Data Loss Demo)

### Concept
Containers by default are ephemeral. If a container crashes, it is restarted but files inside the root directory are reset. If a Pod is deleted, all data inside it is permanently lost. 

An `emptyDir` volume is a temporary volume created when a Pod is assigned to a node. It exists as long as that Pod runs on that node. If the Pod is deleted, the `emptyDir` volume is destroyed as well.

### Manifest: `ephemeral-pod.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ephemeral-pod
spec:
  containers:
  - name: writer
    image: busybox:latest
    command: ["sh", "-c", "echo \"Hello, this was written at $(date)\" > /data/message.txt && sleep 3600"]
    volumeMounts:
    - name: ephemeral-storage
      mountPath: /data
  volumes:
  - name: ephemeral-storage
    emptyDir: {}
```

### Observation and Verification
* **First Run logs/output**: `Hello, this was written at Wed Jun 10 03:04:47 UTC 2026`
* **Recreated logs/output**: `Hello, this was written at Wed Jun 10 03:06:25 UTC 2026`
* **Conclusion**: The timestamp changed completely, indicating that the old file was destroyed along with the first Pod, and a brand-new file was created when the second Pod was launched. This proves `emptyDir` is ephemeral and does not protect against data loss when a Pod is deleted.

### Advanced Concept: Container Crash vs. Pod Deletion
If the *container* crashes or is killed, but the *Pod* itself is not deleted, the `emptyDir` volume survives because its lifecycle is bound to the Pod, not individual containers.

To test this:
1. We wrote a manual file to the volume:
   ```bash
   kubectl exec ephemeral-pod -- sh -c "echo 'I survived the container crash!' > /data/survived.txt"
   ```
2. We attempted to kill the PID 1 process from inside the container (`kill -9 1`), which failed because the Linux kernel protects PID 1 processes inside the container namespace.
3. We stopped the container from the Host node using the runtime interface (`crictl`):
   ```bash
   docker exec -it devops-cluster-control-plane crictl stop f7934c4e40cd6
   ```
4. Verify results:
   - Pod restart count incremented to `1`.
   - Exec'ing back into the container showed `/data/survived.txt` still existed: `I survived the container crash!`.
   
This shows that `emptyDir` protects against container crashes, but NOT against pod restarts, relocations, or deletions.

---

## Task 2: Static Provisioning - Creating a PersistentVolume (PV)

### Concept
A **PersistentVolume (PV)** is a piece of storage in the cluster that has been provisioned by an administrator or dynamically provisioned using Storage Classes. It is a cluster resource, meaning it exists independently of any individual Pod.

### Manifest: `pv.yaml`
We define a PV with:
- **Capacity**: `1Gi` (1 Gigabyte)
- **Access Mode**: `ReadWriteOnce` (Can be mounted as read-write by a single node at a time)
- **Reclaim Policy**: `Retain` (If the claim is deleted, do not delete the physical data on disk; keep it for manual reclamation)
- **HostPath**: `/tmp/k8s-pv-data` (A local folder on the host node)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/tmp/k8s-pv-data"
```

### Observation and Verification
* **PV Status after creation**: `Available` (The PV is successfully registered and is waiting for a PersistentVolumeClaim to bind to it).

---

## Task 3: Create a PersistentVolumeClaim (PVC)

### Concept
A **PersistentVolumeClaim (PVC)** is a developer's request for storage. Instead of specifying the physical storage paths (like `/tmp/k8s-pv-data`), the developer specifies the size and the access modes they need. Kubernetes then automatically finds a matching **Available** PersistentVolume (PV) and binds them together.

### Manifest: `pvc.yaml`
We request:
- **Storage**: `500Mi` (Half of the 1Gi PV we created)
- **Access Mode**: `ReadWriteOnce` (Must match the PV's access mode)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: "" # Force static binding (prevent dynamic provisioning matching)
```

### Observation and Verification
* **PVC Status after creation**: `Bound` to volume `local-pv`
* **PV Status after claim is created**: `Bound` to claim `default/local-pvc`

---

## Task 4: Use the PVC in a Pod (Data Persistence)

### Concept
Now that the PVC is bound to our storage, a developer can mount this PVC into a Pod. If the Pod is deleted and recreated, the new Pod will mount the same PVC, which connects to the same PV, preserving all data.

### Manifest: `pod-pvc.yaml`
We create a Pod that mounts the `local-pvc` claim at `/data` and writes a timestamped line to `/data/message.txt`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-pvc
spec:
  containers:
  - name: writer
    image: busybox:latest
    command: ["sh", "-c", "echo \"Hello, this was written from pod-pvc at $(date)\" >> /data/message.txt && sleep 3600"]
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: local-pvc
```

### Observation and Verification
* **First Pod execution message**: `Hello, this was written from pod-pvc at Wed Jun 10 04:21:48 UTC 2026`
* **Second Pod execution message (after delete & recreate)**:
  ```
  Hello, this was written from pod-pvc at Wed Jun 10 04:21:48 UTC 2026
  Hello, this was written from pod-pvc at Wed Jun 10 04:23:00 UTC 2026
  ```
* **Conclusion**: The file contains logs from both Pod lifecycles. This demonstrates that the PersistentVolumeClaim (PVC) successfully preserved the data across Pod deletion and recreation.

---

## Task 5: StorageClasses and Dynamic Provisioning

### Concept
In static provisioning, the cluster administrator must manually create PVs in advance. This doesn't scale. 

**Dynamic Provisioning** automates this. Instead of creating PVs manually, the administrator creates a **StorageClass**. When a developer requests storage via a PVC and specifies a `storageClassName`, Kubernetes talks to the volume provider (e.g. AWS, GCP, or local provisioner) to dynamically create a matching PV on the fly.

### Command Checks
We inspect the active StorageClasses in our Kind cluster:
- `kubectl get storageclass`
- `kubectl describe storageclass`

### Observation and Verification
* **Default StorageClass Name**: `standard`
* **Provisioner**: `rancher.io/local-path`
* **Reclaim Policy**: `Delete`
* **Volume Binding Mode**: `WaitForFirstConsumer` (Delays volume creation until the Pod using it is scheduled, ensuring the storage is created on the correct node).

---

## Task 6: Dynamic Provisioning in Action

### Concept
In this task, we will create a PersistentVolumeClaim (PVC) that uses our cluster's dynamic StorageClass (`standard`). Because of `VolumeBindingMode: WaitForFirstConsumer`, the PVC will remain in a `Pending` state until we deploy a Pod that references it. Once the Pod starts, Kubernetes will automatically create the PV and bind the claim.

### Manifest: `pvc-dynamic.yaml`
We request `500Mi` of storage using the `standard` StorageClass:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: "standard"
  resources:
    requests:
      storage: 500Mi
```

### Manifest: `pod-dynamic.yaml`
We create a Pod that mounts `dynamic-pvc` at `/data` and writes to it:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-dynamic
spec:
  containers:
  - name: writer
    image: busybox:latest
    command: ["sh", "-c", "echo \"Hello, this was written from pod-dynamic to dynamic-pvc at $(date)\" >> /data/message.txt && sleep 3600"]
    volumeMounts:
    - name: dynamic-storage
      mountPath: /data
  volumes:
  - name: dynamic-storage
    persistentVolumeClaim:
      claimName: dynamic-pvc
```

### Observation and Verification
* **dynamic-pvc status before Pod creation**: `Pending` (due to `WaitForFirstConsumer` binding mode).
* **dynamic-pvc status after Pod creation**: `Bound`
* **PV name dynamically created**: `pvc-76f1dc65-2d32-4230-95f5-ec4a3e032ef4` (500Mi capacity, Delete reclaim policy).

---

## Task 7: Clean Up (Reclaim Policies in Action)

### Concept
When we delete a PVC, what happens to the underlying PV and the physical data? That is determined by the **Reclaim Policy**:
- **Delete**: Kubernetes automatically deletes the PV object and requests the storage provisioner to delete the actual files/disk resources on the server.
- **Retain**: Kubernetes leaves the PV object intact, but changes its status to `Released`. The physical data on the host node is *retained*, and a cluster administrator must clean it up manually.

### Cleanup Procedure
1. Delete all running Pods first:
   ```bash
   kubectl delete pod ephemeral-pod pod-pvc pod-dynamic
   ```
2. Delete both PersistentVolumeClaims:
   ```bash
   kubectl delete pvc local-pvc dynamic-pvc
   ```
3. Check PV status immediately:
   ```bash
   kubectl get pv
   ```

### Observation and Verification
* **Dynamic PV status after PVC deletion**: Deleted automatically (no longer appears in the list).
* **Manual PV status after PVC deletion**: `Released` (retained in the cluster, but no longer bound to an active claim).

4. Manually delete the remaining PV:
   ```bash
   kubectl delete pv local-pv
   ```

---


# Day 56 – Kubernetes StatefulSets

## Task 1: Understand the Problem (Deployment vs. StatefulSet)

### Concept
A **Deployment** is meant for **stateless** applications (like web servers). If a web server Pod dies, a new one is created with a completely random name (e.g. `web-app-abc-123`). This doesn't matter because any web server pod can handle any HTTP request.

However, **stateful** applications (like database clusters) require a stable identity. For example, in a database cluster:
- Each database replica must know who the primary (master) node is (e.g. `db-0`) and who the replica nodes are (`db-1`, `db-2`).
- If a master node crashes, its replacement *must* come back with the exact same name and IP/hostname so the replicas can reconnect to it without cluster reconfiguration.
- Each database replica needs its **own persistent data disk** (it cannot share one volume). If Pod names are random, it's very difficult to map the same disk back to the correct container when it restarts.

### Observation and Verification
* **Deployment Pod names**: Followed a pattern like `nginx-temp-5694769bc6-abc12` (where the suffix is random).
* **Pod replacement name after deletion**: When a Pod was deleted, the replacement Pod received a completely new random suffix (e.g. `nginx-temp-5694769bc6-xyz89`).
* **Conclusion**: Random naming prevents database nodes from discovering each other statically or maintaining stable connection endpoints. If a master node crashes, its replacement will not be reachable at the same hostname.

---

## Task 2: Create a Headless Service

### Concept
A **Headless Service** is a regular service but with `clusterIP: None` specified in its spec. 

Instead of load-balancing traffic and providing a single stable IP (ClusterIP) that routes to backend pods, a Headless Service **directly returns the IP addresses of the individual pods** via DNS records. 

When coupled with a StatefulSet, this allows each Pod to have its own stable DNS hostname (e.g. `web-0.nginx-service.default.svc.cluster.local`), which remains identical even if the Pod is deleted and recreated on a different node.

### Manifest: `service-headless.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
```

### Observation and Verification
* **Headless Service clusterIP**: `None`

---

## Task 3: Create a StatefulSet

### Concept
A **StatefulSet** maintains a sticky identity for each of its Pods. These Pods are created from the same spec, but are not interchangeable: each has a persistent identifier that it maintains across any rescheduling.

- **`serviceName`**: Associates this StatefulSet with our `nginx-headless` service to enable stable DNS hostnames.
- **`volumeClaimTemplates`**: Dynamically provisions a unique PersistentVolumeClaim (PVC) for *each* pod replica.

### Manifest: `statefulset.yaml`
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: nginx
  serviceName: "nginx-headless"
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: web-data
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: web-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "standard" # Uses dynamic local-path provisioner
      resources:
        requests:
          storage: 100Mi
```

### Observation and Verification
* **Startup order of Pods**: Ordered and sequential: `web-0` spawned first, then `web-1`, then `web-2`.
* **PVC names generated**: 
  - `web-data-web-0` (bound to `web-0`)
  - `web-data-web-1` (bound to `web-1`)
  - `web-data-web-2` (bound to `web-2`)

---

## Task 4: Stable Network Identity

### Concept
Each Pod in a StatefulSet derives its hostname from the name of the StatefulSet and the ordinal of the Pod. The format of the DNS name is:

```
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

For our setup, the DNS hostnames are:
- `web-0.nginx-headless.default.svc.cluster.local`
- `web-1.nginx-headless.default.svc.cluster.local`
- `web-2.nginx-headless.default.svc.cluster.local`

This stable hostname remains the same even if the pod is rescheduled to another node and gets a new internal IP address. Other pods can reliably communicate with specific database nodes using these static DNS names.

### Observation and Verification
* **Pod web-0 internal IP**: `10.244.0.24`
* **nslookup resolution result for web-0**: `10.244.0.24`
* **Do they match?**: Yes, the DNS entry resolved by CoreDNS maps exactly to the pod's internal IP.

---

## Task 5: Stable Storage (Data Persistence across Pod Deletion)

### Concept
Deployments use a shared volume for all replicas, but a StatefulSet uses `volumeClaimTemplates` to allocate an independent PVC for each replica. 

Because the Pod name (`web-0`) and the PVC name (`web-data-web-0`) are stable, if `web-0` is deleted, its replacement Pod will mount the exact same `web-data-web-0` PVC and recover the data.

### Observation and Verification
- Data written to `web-0`: `Data from web-0`
- Data read from recreated `web-0`: `Data from web-0`
- Do they match? (Did the data survive?): Yes, the data survived because the new pod mounted the same PersistentVolumeClaim (`web-data-web-0`).

---

## Task 6: Ordered Scaling

### Concept
StatefulSets scale up and down in a strict, sequential order:
- **Scaling Up**: Pods are created one-by-one in ascending order (e.g. `web-3` first, then `web-4`).
- **Scaling Down**: Pods are terminated in **reverse order** (descending) (e.g. `web-4` first, then `web-3`).

Furthermore, when scaling down, Kubernetes **never deletes the PersistentVolumeClaims (PVCs)**. This is a safety feature: if you scale down a database cluster, you do not want to destroy your backup replicas' data. If you scale back up, the new pod will attach to the existing PVC and immediately start syncing.

### Observation and Verification
* **Total PVCs existing after scaling down to 3**: `5` (All PVCs from `web-0` to `web-4` are retained, demonstrating that scaling down a StatefulSet does not delete its PVCs).

---

## Task 7: Clean Up

### Concept
Just like scaling down, deleting the entire StatefulSet **does not delete the PVCs**. This is the ultimate safety mechanism in Kubernetes to prevent data loss. You must delete the PVCs manually when you are finished.

### Cleanup Procedure
1. Delete the StatefulSet and the Headless Service:
   ```bash
   kubectl delete statefulset web
   kubectl delete service nginx-headless
   ```
2. Verify that the PVCs still exist:
   ```bash
   kubectl get pvc
   ```
3. Manually delete the remaining PVCs:
   ```bash
   kubectl delete pvc web-data-web-0 web-data-web-1 web-data-web-2 web-data-web-3 web-data-web-4
   ```

### Observation and Verification
* **Do PVCs survive StatefulSet deletion?**: Yes, they survived the StatefulSet deletion and remained in the cluster, requiring manual deletion (or `kubectl delete pvc --all`) to clean up completely.

---

## Comparison Summary: Deployment vs. StatefulSet

| Feature | Deployment | StatefulSet |
|---|---|---|
| **Use Case** | Stateless apps (Web APIs, Frontends) | Stateful apps (Databases, Message Queues) |
| **Pod Naming** | Random suffix (e.g. `web-app-abc-123`) | Sequential ordinals (e.g. `web-0`, `web-1`) |
| **Startup / Scale Up** | Non-ordered (concurrent startup) | Sequential order (`0` to `N-1`) |
| **Shutdown / Scale Down**| Concurrent shutdown | Reverse sequential order (`N-1` to `0`) |
| **Storage Mapping** | Shared volume claim among all pods | Individual volume claim per pod replica |
| **Network Identity** | No stable DNS per pod | Unique stable DNS per pod linked via Headless Service |

---

## What I Learned
1. **Sticky Pod Identity**: StatefulSet pods have persistent index numbers. When a pod restarts, it retains its name and mounts its corresponding PVC.
2. **Headless Services (`clusterIP: None`)**: Used to directly resolve individual Pod IPs via DNS instead of load-balancing to a single service IP.
3. **Sequential Scaling**: Pods are scaled sequentially in ascending order and terminated in reverse descending order to prevent race conditions during leader/follower configuration.
4. **Volume Claim Templates**: Auto-generates independent storage volumes for each pod replica.
5. **Safety by Default**: Scaling down or deleting a StatefulSet preserves the PVCs so that database data is never lost accidentally.


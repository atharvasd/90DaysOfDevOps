# Day 54 – Kubernetes ConfigMaps and Secrets

## What Are ConfigMaps and Secrets?

In a native Kubernetes environment, you want to follow the **12-Factor App** methodology by separating your application code (container images) from your configuration settings. 

Kubernetes provides two API resources to store configuration data decoupled from the pod lifecycle:

| Resource | Purpose | Stored Format | Example Use Cases |
|---|---|---|---|
| **ConfigMap** | Storing non-sensitive configuration settings. | Plaintext (key-value pairs or file contents). | Port numbers, environment designations (`dev`/`prod`), feature flags, application config files (`nginx.conf`). |
| **Secret** | Storing sensitive information. | Base64-encoded (stored in-memory on nodes). | DB passwords, private API keys, TLS certificates, OAuth tokens. |

---

## 1. Creating ConfigMaps

We can create ConfigMaps using **literals** (typed directly in the command line) or **files** (importing local files).

### Creating from Literals (Task 1)
Created the ConfigMap `app-config` with three key-value pairs:
```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_DEBUG=false \
  --from-literal=APP_PORT=8080
```

When inspecting this with `kubectl get configmap app-config -o yaml`, we see the values are stored as plaintext under the `data:` block:
```yaml
apiVersion: v1
data:
  APP_DEBUG: "false"
  APP_ENV: production
  APP_PORT: "8080"
kind: ConfigMap
metadata:
  name: app-config
```

### Creating from a File (Task 2)
We wrote a custom Nginx configuration file (`default.conf`) that includes a `/health` endpoint returning `healthy`:
```nginx
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
    }
    location /health {
        default_type text/plain;
        return 200 "healthy\n";
    }
}
```

We created the ConfigMap `nginx-config` using `--from-file`:
```bash
kubectl create configmap nginx-config --from-file=default.conf=default.conf
```
* **Key (`default.conf`)**: Becomes the filename when we mount this ConfigMap as a volume.
* **Value**: Stores the entire contents of our local `default.conf` file.

---

## 2. Using ConfigMaps in a Pod (Task 3)

There are two primary ways to consume ConfigMaps inside a Pod:

### Method A: Environment Variables
Ideal for individual, simple settings. We used `envFrom` with `configMapRef` to automatically inject all key-value pairs from `app-config` as environment variables:

```yaml
# pod-env.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-env
spec:
  containers:
    - name: pod-env
      image: busybox:latest
      command: ["sh", "-c", "env | grep APP_"]
      envFrom:
        - configMapRef:
            name: app-config
```

**Output of `kubectl logs pod-env`:**
```
APP_DEBUG=false
APP_PORT=8080
APP_ENV=production
```

### Method B: Volume Mounts
Ideal for full configuration files. We mounted our `nginx-config` ConfigMap as a volume at `/etc/nginx/conf.d`:

```yaml
# pod-volume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-volume
spec:
  containers:
    - name: nginx-server
      image: nginx:1.25
      ports:
        - containerPort: 80
      volumeMounts:
        - name: nginx-config-volume
          mountPath: /etc/nginx/conf.d
  volumes:
    - name: nginx-config-volume
      configMap:
        name: nginx-config
```

**Testing the mount with curl:**
```bash
kubectl exec pod-volume -- curl -s http://localhost/health
# Output: healthy
```

---

## 3. Creating and Consuming Secrets (Task 4 & 5)

### base64 is Encoding, NOT Encryption!
When we created the `db-credentials` secret:
```bash
kubectl create secret generic db-credentials \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASSWORD=s3cureP@ssw0rd
```

And inspected the output (`kubectl get secret db-credentials -o yaml`):
```yaml
apiVersion: v1
data:
  DB_PASSWORD: czNjdXJlUEBzc3cwcmQ=
  DB_USER: YWRtaW4=
kind: Secret
...
```
The password values are base64-encoded. However, this is **not secure** on its own. Anyone with API access or the base64 string can decode it instantly:
```bash
echo 'czNjdXJlUEBzc3cwcmQ=' | base64 --decode
# Output: s3cureP@ssw0rd
```
**Why use Secrets then?**
- Kubernetes stores them in a memory-backed file system (`tmpfs`) on the nodes so they are never written to physical disk.
- You can restrict access to Secrets using **RBAC (Role-Based Access Control)** separately from ConfigMaps.
- You can enable **Encryption at Rest** in the Kubernetes API server so that raw values are encrypted inside `etcd`.

### Consuming Secrets in a Pod
We wrote `pod-secret.yaml` which injects `DB_USER` as an environment variable using `secretKeyRef` and mounts the entire Secret folder at `/etc/db-credentials`:

```yaml
# pod-secret.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-secret
spec:
  containers:
    - name: app-container
      image: busybox:latest
      command:
        [
          "sh",
          "-c",
          'echo "DB_USER Env Var: $DB_USER" && echo "--- Volume Mount Files: ---" && cat /etc/db-credentials/DB_USER && echo "" && cat /etc/db-credentials/DB_PASSWORD && echo "" && sleep 3600',
        ]
      env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: DB_USER
      volumeMounts:
        - name: secret-volume
          mountPath: /etc/db-credentials
          readOnly: true
  volumes:
    - name: secret-volume
      secret:
        secretName: db-credentials
```

**Logs Output (`kubectl logs pod-secret`):**
```
DB_USER Env Var: admin
--- Volume Mount Files: ---
admin
s3cureP@ssw0rd
```
Notice that inside the container volume mount, Kubernetes **automatically decodes the values back to plaintext files**. The container reads `admin` and `s3cureP@ssw0rd` directly.

---

## 4. Environment Variables vs. Volume Mount Updates (Task 6)

How do updates propagate when we modify a ConfigMap or Secret in the Kubernetes API?

1. **Environment Variables**:
   - Injected into the container's process environment at startup.
   - **Do NOT update dynamically**. If you edit the ConfigMap, the pod's env vars will keep the old values until the pod is deleted and redeployed.

2. **Volume Mounts**:
   - The Kubelet daemon polls the API server for changes to mounted ConfigMaps/Secrets.
   - When a change is detected, it updates the files inside the pod directory dynamically (usually takes **30–60 seconds** due to cache sync intervals).
   - **Updates dynamically without pod restarts**.

### Dynamic Update Verification
We ran a test pod (`pod-live`) reading a mounted ConfigMap file (`/etc/config/message`) in a loop:
```
File Message: hello
File Message: hello
File Message: hello
```

Then we patched the ConfigMap:
```bash
kubectl patch configmap live-config --type merge -p '{"data":{"message":"world"}}'
```

Without restarting the pod, the logs automatically updated to reflect the new value:
```
File Message: hello
File Message: hello
File Message: world
File Message: world
```

---

## What I Learned
- **Decoupling Config**: ConfigMaps and Secrets keep container images clean and reusable across different environments (dev/stage/prod).
- **Consuming Patterns**: Use environment variables for simple configs, and volume mounts for configuration files or dynamic secrets.
- **base64 isn't Security**: Secrets are only encoded by default; encryption must be configured at the API server / etcd layer, and access must be secured with RBAC.
- **Propagation Logic**: Volume-mounted ConfigMaps auto-update asynchronously, while environment variables require a pod restart.

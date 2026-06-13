# Day 60 Capstone: Concept Notes

This file contains explanations and notes gathered during the execution of the Day 60 Capstone project.

---



## 📝 Task 2: MySQL & StatefulSets

### Why do we need Kubernetes Secrets?
Why not just hardcode the database passwords directly into the StatefulSet or a ConfigMap?
1. **No Passwords in Git:** Your StatefulSet YAML files are usually committed to GitHub. If you hardcode passwords there, they are exposed to the world. By putting them in a `Secret`, you can inject them at runtime without saving them in your codebase.
2. **Strict Access Control (RBAC):** In a real company, Junior Developers might be granted permissions to view `Deployments` and `ConfigMaps`, but only the Lead DevOps engineer can view `Secrets`. Separating them allows for strict security policies.
3. **Encryption at Rest:** Kubernetes `Secrets` are encrypted when stored in the cluster's internal database (`etcd`). `ConfigMaps` are stored in plain text.
4. **Runtime Injection:** Using `envFrom: secretRef`, the secret is injected securely into the pod's RAM as an environment variable only while it is running.

### But wait, if we write `secret.yaml`, aren't we still hardcoding the password in Git?
Yes! This is the classic "Last Mile Problem" in GitOps. If you create a `secret.yaml` with your real password and push it to GitHub, your password is leaked, defeating the entire purpose of the Kubernetes Secret. 

In a real production environment, you **never** commit a plain `secret.yaml`. Instead, you use one of these three DevSecOps patterns:
1. **Sealed Secrets (Bitnami):** You encrypt your `secret.yaml` on your laptop using a special public key. This generates an encrypted `SealedSecret.yaml`. You commit the encrypted file to Git. The Kubernetes cluster holds the private key and automatically decrypts it back into a usable Secret.
2. **External Secrets Manager (Vault, AWS Secrets Manager, GCP Secret Manager):** You commit an `ExternalSecret.yaml` file that contains no passwords. It simply tells Kubernetes: *"Go talk to AWS Secrets Manager, fetch the password named `prod-db-pass`, and inject it here."*
3. **CI/CD Injection:** You store the password securely in GitHub Actions (or Jenkins). You commit a YAML file with a placeholder (like `password: ${DB_PASS}`). When your pipeline deploys the code, it swaps the placeholder with the real password right before sending it to Kubernetes.

*For this Capstone project, since it is a learning lab, you can just use dummy passwords (like `admin123`) or add your `01-mysql-secret.yaml` file to your `.gitignore` so it never gets pushed to GitHub.*

### Why do we need a Headless Service (`clusterIP: None`)?
Databases are "Stateful" (they hold unique data), and normal Services are designed for "Stateless" apps (like web servers). 
- A normal Service acts like a Load Balancer and gets its own IP address, distributing traffic randomly to pods. You cannot send a "WRITE" command to a random database pod (like a read-replica), or your data will corrupt.
- A **Headless Service** does *not* act as a load balancer and does *not* get an IP address. Instead, it creates a specific, permanent DNS URL for *every single individual pod* in the StatefulSet (e.g., `mysql-0.mysql.capstone.svc.cluster.local`). This allows WordPress to reliably target the exact primary database pod.

### What happens when the Master Pod (`mysql-0`) crashes?
If you used a normal Deployment, Kubernetes would spin up a new pod with a random name (like `mysql-8f7b5`) and it would start with a blank hard drive. All data would be lost.

Because we use a **StatefulSet + Headless Service**:
1. **The Data Survives:** The database files are stored on a Persistent Volume (PVC), which is strictly bound to the name `mysql-0`.
2. **Predictable Resurrection:** The StatefulSet spins up a brand new pod and forces it to have the exact same name: `mysql-0`.
3. **Reattaching the Hard Drive:** Because the new pod is named `mysql-0`, Kubernetes automatically reattaches the exact same Persistent Volume. All old data is perfectly intact.
4. **DNS Recovers Instantly:** The Headless Service detects the new pod, updates the DNS, and the traffic instantly routes to the new IP address. WordPress reconnects, and zero data is lost.

---

## 📝 Task 3: Deploying WordPress (Deployments & Probes)

### Why use a ConfigMap instead of just hardcoding the DB URL?
A ConfigMap decouples configuration from your code. If you decide to move your database to AWS RDS later, you don't have to rewrite your Deployment YAML or rebuild your Docker image. You just update the ConfigMap, and WordPress instantly connects to the new database!

### `envFrom` vs `env` (Secret Mapping)
- **`envFrom`** is a shortcut that dumps every single variable inside a ConfigMap directly into the container.
- **`env`** allows you to explicitly map variables. We had to use this for the Secret because our Secret contained `MYSQL_USER`, but the WordPress container was hardcoded to look for `WORDPRESS_DB_USER`. By using `env` and `valueFrom.secretKeyRef`, we essentially acted as a translator between our backend and our frontend.

### Why do we need BOTH Liveness and Readiness Probes?
They sound similar, but they do two completely different jobs:
1. **Liveness Probe (The Medic):** It constantly pings `/wp-login.php`. If it gets an error (like a 500 Internal Server Error because PHP crashed), it literally kills the container and restarts it. It is your automatic self-healing mechanism.
2. **Readiness Probe (The Traffic Cop):** When a pod first boots up, it takes about 20 seconds for Apache and PHP to start. If the Kubernetes Service immediately sends user traffic to it, users will see a "Connection Refused" error. The Readiness Probe checks `/wp-login.php`, and *only* allows the Service to send user traffic to the pod once the probe gets a successful 200 OK HTTP response.

### Why did we add `initialDelaySeconds: 30`?
Without this delay, Kubernetes would check the Liveness probe at exactly second #1. WordPress wouldn't be booted yet, so the probe would fail. Kubernetes would kill the pod and restart it. Second #1 hits again, it fails again, and it restarts again. You end up in an infinite `CrashLoopBackOff`. The delay gives the container 30 seconds of "grace period" to start up before the medic starts checking its pulse!

---

## 📝 Task 4: Exposing WordPress (Services)

### Why did we use a `NodePort` Service?
Kubernetes has three main types of Services for routing traffic:
1. **ClusterIP (Default):** This gives the service an internal IP address. It is strictly for backend-to-backend communication (like how WordPress talks to MySQL). If we used a ClusterIP for WordPress, you wouldn't be able to open it in your laptop's web browser because it's locked inside the cluster firewall.
2. **NodePort:** This tells Kubernetes: *"Take a port (like `30080`) and punch a hole through the physical server's firewall. Anyone who hits the physical server on `30080` gets forwarded to this pod."* This is the easiest way to access an application from outside the cluster during local development.
3. **LoadBalancer:** This is the standard for Cloud Production (AWS/GCP). It tells AWS to literally provision a physical load balancer with a public IP address. Since we are running locally on a laptop, a LoadBalancer usually doesn't work out-of-the-box (it just hangs in "Pending" state).

### Task 6: Horizontal Pod Autoscaler (HPA)

### Why does the Deployment need `resources.requests` for the HPA to work?
If you create an HPA that says "Scale up when CPU hits 50%", Kubernetes needs to do some math. It divides your *current* CPU usage by your *requested* CPU baseline.
If you never defined a `requests.cpu` in your Deployment YAML, Kubernetes doesn't know what "100%" is! Because it has no baseline, it cannot mathematically calculate what 50% is. The HPA will show `<unknown>/50%` in the terminal and will **never** scale your pods. Therefore, CPU requests are absolutely mandatory for an HPA to function.

### How do we calculate the requested resources (`cpu: 250m`)?
In the real world, you do not just guess these numbers! Here is the methodology:
1. **The Baseline Rule of Thumb:** For a standard Apache/PHP container like WordPress, `250m` (1/4 of a CPU core) and `256Mi` of RAM is the industry standard baseline for it to sit idle without throwing "Out of Memory" (OOMKilled) errors.
2. **The HPA Math:** If we request `250m`, the HPA "50%" target means the HPA will scale up as soon as the pod hits `125m` of CPU usage. If we had requested a massive `1000m` (1 full core), the pod would have to get hit with enough traffic to reach `500m` of CPU before the HPA triggers, which might be too late to save the website! Setting a lower, realistic baseline ensures it scales quickly.
3. **Continuous Monitoring:** In production, you deploy with a baseline, and then you use monitoring tools (like Prometheus or Grafana) to watch the actual usage over a week. If WordPress never goes above `100m`, you lower your request to save money on cloud bills. (There is even a Kubernetes tool called VPA—Vertical Pod Autoscaler—that watches your pods and literally tells you what the numbers should be!).

---

## 📝 Task 7: Helm (The Package Manager)

### What is Helm and why do we need it?
Helm is a package manager for Kubernetes (exactly like `brew` for Mac, `apt` for Linux, or `npm` for Node.js). 

Think about the Capstone project you just built. To install one single application (WordPress), you had to manually write and manage 7 different YAML files (Namespace, Secret, ConfigMap, StatefulSet, Deployment, Headless Service, NodePort Service, HPA). 

Now imagine you want to install a massive enterprise tool like Prometheus (for monitoring) or GitLab. That could require writing over **50+ YAML files**! 

Helm solves this by bundling all of those YAML files into a single zip-like folder called a **"Chart"**.
Instead of writing 50 files, you simply type `helm install bitnami/wordpress`. Helm downloads the Chart, automatically generates all the Deployments, Services, and Secrets, and applies them to your cluster instantly. It takes hours of manual YAML writing and turns it into a 5-second command.


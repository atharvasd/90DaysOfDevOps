# Professional Naming Conventions (Standardization)

To keep the Capstone organized and professional, we are standardizing all names across the project using industry best practices.

## 1. File Names
Use **numbered prefixes** so that a CI/CD pipeline (or another engineer) knows exactly what order to apply the files in. Use lowercase `kebab-case`.
- `00-namespace.yaml`
- `01-mysql-secret.yaml`
- `02-mysql-headless-svc.yaml`
- `03-mysql-statefulset.yaml`
- `04-wordpress-configmap.yaml`
- `05-wordpress-deployment.yaml`
- `06-wordpress-nodeport-svc.yaml`
- `07-wordpress-hpa.yaml`

## 2. Kubernetes Resource Names (`metadata.name`)
Use clean, simple `kebab-case`. Do not append the resource type to the name (e.g., call a deployment `wordpress`, not `wordpress-deployment`), unless you need to differentiate services.
- Namespace: `capstone`
- Secret: `mysql-auth`
- StatefulSet: `mysql`
- Headless Service: `mysql-headless` (so you know it's headless)
- Deployment: `wordpress`
- NodePort Service: `wordpress` (It is perfectly fine for a Service and a Deployment to share the exact same name).

## 3. Variables & Secrets
Environment variables should always be **SCREAMING_SNAKE_CASE** and must exactly match what the container images expect, as defined in the Capstone task instructions:

**MySQL Variables:**
- `MYSQL_ROOT_PASSWORD`
- `MYSQL_DATABASE`
- `MYSQL_USER`
- `MYSQL_PASSWORD`

**WordPress Variables:**
- `WORDPRESS_DB_HOST`
- `WORDPRESS_DB_NAME`
- `WORDPRESS_DB_USER`
- `WORDPRESS_DB_PASSWORD`

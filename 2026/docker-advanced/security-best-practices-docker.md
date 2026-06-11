# Docker Security Best Practices — Container Hardening Guide

A comprehensive guide to securing Dockerfiles, images, and container runtimes.

---

## 🛑 1. Never Run as Root

By default, Docker containers run as the `root` user (UID 0). If an attacker breaks out of the container, they have root access to the host machine.

### The Rule: Always specify a non-root user
```dockerfile
# ❌ BAD: Runs as root
FROM node:20
WORKDIR /app
COPY . .
RUN npm install
CMD ["node", "server.js"]

# ✅ GOOD: Create and use a dedicated user
FROM node:20
WORKDIR /app
# Create a non-root user and group
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
# Give the user ownership of the app directory
COPY --chown=appuser:appgroup . .
RUN npm install
# Switch to the non-root user
USER appuser
CMD ["node", "server.js"]
```

---

## 🔑 2. Never Bake Secrets into Layers

If you use `ENV` or `ARG` to pass a secret during the build, or if you `COPY` a secret file and `RUN rm` it, **the secret is still in the image layers forever** and can be viewed with `docker history`.

### The Fix: Use BuildKit Secrets
BuildKit allows you to mount secrets temporarily during a specific `RUN` step without saving them to the image history.

```dockerfile
# ❌ BAD: Secret baked into layer
ENV NPM_TOKEN="ghp_mySuperSecretToken"
RUN npm config set //registry.npmjs.org/:_authToken ${NPM_TOKEN}
RUN npm install

# ✅ GOOD: Mount secret temporarily
# Run the build with: docker build --secret id=npm_token,src=./.npm_token .
RUN --mount=type=secret,id=npm_token \
    npm config set //registry.npmjs.org/:_authToken $(cat /run/secrets/npm_token) && \
    npm install
```

---

## 🗑️ 3. Use `.dockerignore`

If you use `COPY . .`, you are likely copying sensitive files (`.git`, `.env`, SSH keys) or bloated directories (`node_modules`) into your image.

### The Fix
Always include a `.dockerignore` file at the root of your project:
```text
.git
.env
node_modules
npm-debug.log
Dockerfile
.dockerignore
```

---

## 📦 4. Minimal Base Images

Large base images (like `ubuntu` or `node`) contain hundreds of unnecessary packages and OS utilities (curl, wget, bash, package managers) that increase the attack surface.

### The Fix: Alpine or Distroless
```dockerfile
# ❌ BAD: 1GB+, 100+ vulnerabilities
FROM node:20

# ✅ GOOD: Alpine (50MB, uses musl libc)
FROM node:20-alpine

# ✅ BEST: Distroless (No shell, no package manager — just the runtime)
FROM gcr.io/distroless/nodejs20-debian12
```

---

## 🛡️ 5. Runtime Security

Security doesn't stop at the `Dockerfile`. When running the container, restrict its access to the host OS.

### Read-Only Root Filesystem
Prevent attackers from downloading malware or modifying scripts by making the container's root filesystem read-only.
```bash
docker run --read-only -v /app/tmp:/tmp my-app
```

### Drop Capabilities
By default, Docker grants several Linux kernel capabilities to containers. Drop all capabilities and only add back what is strictly necessary.
```bash
# Drop everything, then add back only what's needed to bind to port 80
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE my-app
```

---

## 🛡️ Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **Users** | `USER appuser` (Never run as root) | 🔴 Critical |
| **Secrets** | Use `RUN --mount=type=secret` for build-time credentials | 🔴 Critical |
| **Context** | Use `.dockerignore` to prevent accidental secret leakage | 🔴 Critical |
| **Images** | Use Alpine or Distroless base images | 🟡 High |
| **Images** | Scan images with Trivy (`trivy image myapp:latest`) | 🔴 Critical |
| **Runtime** | Use `--read-only` root filesystems | 🟡 High |
| **Runtime** | Use `--cap-drop=ALL` | 🟡 High |

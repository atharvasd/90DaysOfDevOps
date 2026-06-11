# Lab 02: Advanced Docker Compose (Profiles, Overrides, Healthchecks)

**Topic:** Advanced local development workflows

---

## Overview

As applications grow, a single `docker-compose.yml` isn't enough. You might need different environments (dev vs prod), or want to selectively run parts of the stack (e.g., run the DB but not the frontend).

### Key Concepts
- **Profiles** — Group services together so you only start what you need.
- **Override Files** — Merge multiple compose files (`docker-compose.yml` + `docker-compose.override.yml`) for environment-specific configs.
- **Healthchecks & `depends_on`** — Ensure services start in the exact correct order.

---

## 🛠️ Hands-on Tasks

### Task 1: Compose Profiles

Imagine a stack with a database, a backend, a frontend, and a heavy data-processing worker. Sometimes developers only want to work on the frontend.

**`docker-compose.yml`**:
```yaml
version: '3.9'

services:
  database:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD: secret
    # No profile defined -> belongs to the "default" profile

  backend:
    image: my-backend:latest
    ports:
      - "8080:8080"
    profiles: ["api", "full"]

  frontend:
    image: my-frontend:latest
    ports:
      - "3000:3000"
    profiles: ["frontend", "full"]

  data-worker:
    image: my-heavy-worker:latest
    profiles: ["full", "worker-only"]
```

**Testing Profiles:**
```bash
# Starts ONLY the database (the default profile)
docker compose up -d

# Starts DB + Backend (the 'api' profile)
docker compose --profile api up -d

# Starts everything (the 'full' profile)
docker compose --profile full up -d
```

### Task 2: Override Files (Dev vs Prod)

By default, `docker compose up` automatically reads `docker-compose.yml` AND `docker-compose.override.yml`, merging them together. This is perfect for local development.

**`docker-compose.yml` (Base / Production-like)**:
```yaml
version: '3.9'
services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
```

**`docker-compose.override.yml` (Local Dev Only)**:
```yaml
version: '3.9'
services:
  web:
    # Expose a different port locally to avoid conflicts
    ports:
      - "8080:80"
    # Mount local source code
    volumes:
      - ./html:/usr/share/nginx/html
```

When you run `docker compose up` locally, Nginx will map port 8080 and mount your code. In production, you run `docker compose -f docker-compose.yml up` to ignore the override file.

### Task 3: Robust Startup with Healthchecks

Standard `depends_on` only waits for a container to *start*, not to be *ready*. If your backend crashes because Postgres is still booting, you need Healthchecks.

```yaml
version: '3.9'

services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD: secret
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  api:
    image: my-backend:latest
    depends_on:
      db:
        condition: service_healthy # Wait until the healthcheck passes!
```

---

## ✅ Best Practices
- **Use `.env` files**: Keep secrets and environment-specific variables in a `.env` file, which Docker Compose automatically loads.
- **Network Isolation**: Don't put the database port in the `ports` mapping unless you need external access. If the backend needs to reach the DB, they can communicate purely over the internal Docker network.

# Lab 01: Docker Buildx and Multi-Architecture Images

**Topic:** Advanced Docker — Building for AMD64 (Intel/AMD) and ARM64 (Apple Silicon/AWS Graviton)

---

## Overview

With the rise of Apple Silicon (M1/M2/M3) and AWS Graviton processors, Docker containers must increasingly run on `arm64` architecture. If you build an image on an Intel machine (`amd64`) and try to run it on a Mac M-series, it will either fail or run slowly via emulation.

**Docker Buildx** is a CLI plugin that extends the `docker build` command with the full support of the features provided by Moby BuildKit builder toolkit, including the ability to build multi-architecture images in a single command.

---

## 🛠️ Hands-on Tasks

### Task 1: Check Current Builder

Verify you have Buildx installed and check the default builder.

```bash
docker buildx version
docker buildx ls
```

By default, Docker uses the `default` builder, which doesn't support multi-arch builds out of the box.

### Task 2: Create a Multi-Arch Builder

Create a new builder instance that supports multiple architectures and switch to it.

```bash
docker buildx create --name mybuilder --use
docker buildx inspect --bootstrap
```

You should now see platforms like `linux/amd64`, `linux/arm64`, etc., listed under your builder.

### Task 3: Write a Simple Application

Create a small Go application to test architecture compilation.

```bash
mkdir multi-arch-test && cd multi-arch-test
```

**`main.go`**:
```go
package main

import (
	"fmt"
	"runtime"
)

func main() {
	fmt.Printf("Hello from Docker! I am running on architecture: %s\n", runtime.GOARCH)
}
```

**`Dockerfile`**:
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY main.go .
RUN go build -o hello main.go

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/hello .
CMD ["./hello"]
```

### Task 4: Build and Push for Multiple Architectures

Unlike standard `docker build`, multi-arch builds using `buildx` usually need to be pushed directly to a registry (like Docker Hub) because the local Docker engine's image store doesn't fully support multi-arch manifests yet.

```bash
# Log in to Docker Hub first
docker login

# Build for both AMD64 and ARM64, and push the manifest to Docker Hub
# Replace <your-dockerhub-username> with your actual username
docker buildx build --platform linux/amd64,linux/arm64 -t <your-dockerhub-username>/multi-arch-test:v1 --push .
```

### Task 5: Verify the Manifest

A multi-arch image on Docker Hub is actually a "Manifest List" — a JSON file that points to different images based on the client's architecture.

```bash
# Inspect the manifest list remotely
docker buildx imagetools inspect <your-dockerhub-username>/multi-arch-test:v1
```

You will see output detailing the hashes for both the `linux/amd64` and `linux/arm64` variants. When someone runs `docker pull` on an M1 Mac, Docker automatically reads the manifest and pulls the `arm64` variant.

---

## ✅ Best Practices
- **Always use BuildKit**: Modern Docker features (like multi-arch, advanced caching, and secrets) require BuildKit. It is enabled by default in recent Docker versions, but you can explicitly enable it via `DOCKER_BUILDKIT=1`.
- **CI/CD Integration**: When building in GitHub Actions, use `docker/setup-qemu-action` and `docker/setup-buildx-action` to enable multi-arch builds in your CI pipeline.

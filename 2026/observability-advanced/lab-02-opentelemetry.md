# Lab 02: OpenTelemetry Tracing Basics

**Topic:** Advanced Observability

---

## Overview

Metrics (Prometheus) tell you *that* a system is failing. Logs (Loki) tell you *why* a specific component failed. But in a microservices architecture, when a user clicks "Checkout" and it takes 5 seconds, how do you know which of the 10 microservices caused the delay?

**Distributed Tracing** solves this. It injects a "Trace ID" into the initial HTTP request and passes it along to every downstream database query and API call.

**OpenTelemetry (OTel)** is the modern standard for generating and collecting these traces.

---

## 🛠️ Hands-on Tasks

### Task 1: Understand the Terminology
- **Trace:** The entire journey of a request (e.g., User Checkout).
- **Span:** A single operation within that trace (e.g., DB Query `SELECT * FROM users`, or an API call to the Payment Service).
- **OTel Collector:** A vendor-agnostic proxy that receives spans from your apps and exports them to a backend (Jaeger, Datadog, Tempo).

### Task 2: Instrument an Application (Python Example)

Instead of manually writing timing code, OpenTelemetry can auto-instrument most languages.

1. **Install OTel packages:**
```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install
```

2. **Run your app with Auto-Instrumentation:**
You do NOT need to modify your source code!
```bash
export OTEL_SERVICE_NAME="payment-service"
export OTEL_TRACES_EXPORTER="otlp"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"

# Wrap your startup command with the OTel instrumentor
opentelemetry-instrument python myapp.py
```

### Task 3: Deploy Jaeger for Trace Visualization

Jaeger is a popular open-source backend for viewing traces.

1. **Run Jaeger locally:**
```bash
docker run -d --name jaeger \
  -p 16686:16686 \
  -p 4317:4317 \
  jaegertracing/all-in-one:latest
```
*Port 4317 is where the OTel instrumentor sends data. Port 16686 is the Jaeger UI.*

2. **Generate Traffic:**
Send a few curl requests to your `myapp.py`.

3. **View the Traces:**
Open `http://localhost:16686` in your browser. Search for `payment-service`. You will see a visual Gantt chart showing exactly how many milliseconds each function and database query took.

---

## ✅ Best Practices
- **Standardize on OTel:** Never use vendor-specific SDKs (like Datadog's or New Relic's) inside your application code. Always use OpenTelemetry. You can configure the OTel Collector to forward the data to any vendor without changing your app code.
- **Trace Context Propagation:** Ensure your load balancers (like Nginx or Envoy) are configured to forward `traceparent` HTTP headers, otherwise traces will break when moving between services.

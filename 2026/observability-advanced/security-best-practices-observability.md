# Observability Security Best Practices

A guide to securing your monitoring infrastructure. Observability tools collect sensitive operational data, API keys from metrics endpoints, and user data from logs. If left unsecured, an attacker can use Grafana to map your entire network topology.

---

## 🛑 1. Do Not Expose Metrics Endpoints

Prometheus pulls metrics by sending HTTP GET requests to `/metrics` endpoints on your applications.

### The Vulnerability
If your `/metrics` endpoint is exposed to the public internet, attackers can scrape it. Metrics often reveal software versions, active user counts, and sometimes accidentally expose API tokens if developers log them.

### The Fix
Never expose `/metrics` through your Ingress controller or Load Balancer.
- Use internal Kubernetes network routing (ClusterIP).
- If you must scrape metrics across the internet, require **Mutual TLS (mTLS)** or strong HTTP Basic Authentication on the `/metrics` endpoint.

---

## 🔐 2. Securing Grafana and Prometheus UI

By default, Prometheus has NO authentication. Anyone who can reach the Prometheus UI can execute PromQL queries and see all your data.

### The Fix: Reverse Proxy (OAuth2)
Do not expose Prometheus directly. Place it behind a reverse proxy like **OAuth2 Proxy** or **NGINX**.

```yaml
# Example: Using oauth2-proxy as a sidecar for Prometheus
containers:
  - name: prometheus
    image: prom/prometheus
    # Listen only on localhost!
    args: ["--web.listen-address=127.0.0.1:9090"]
  - name: oauth2-proxy
    image: quay.io/oauth2-proxy/oauth2-proxy:v7.4.0
    args:
      - --upstream=http://127.0.0.1:9090
      - --provider=github
      - --github-org=my-company
```
*This setup ensures that only members of the `my-company` GitHub organization can view the Prometheus UI.*

---

## 🗑️ 3. Scrub Sensitive Data from Logs (Loki)

Developers frequently log sensitive data by accident (e.g., `logger.info(request.body)` where the body contains a plaintext password or credit card).

### The Fix: Log Redaction at the Edge
Use Promtail or the OTel Collector to scrub sensitive data *before* it is sent to Loki.

```yaml
# promtail-config.yaml
pipeline_stages:
  - match:
      selector: '{app="payment-service"}'
      stages:
        - replace:
            expression: '(?i)(password|credit_card|secret)="?([^"\s]+)"?'
            replace: '***REDACTED***'
```

---

## 🛡️ Security Checklist

| Category | Best Practice | Priority |
|---|---|---|
| **Access** | Never expose `/metrics` endpoints publicly | 🔴 Critical |
| **Access** | Place Prometheus/Alertmanager UIs behind an authenticating proxy (OIDC/OAuth2) | 🔴 Critical |
| **Logs** | Redact passwords and PII at the collector level (Promtail/Fluentd) before storage | 🔴 Critical |
| **Grafana** | Disable anonymous access in Grafana (`[auth.anonymous] enabled = false`) | 🟡 High |
| **Grafana** | Enforce SSO for Grafana logins (Google, GitHub, SAML) | 🟡 High |

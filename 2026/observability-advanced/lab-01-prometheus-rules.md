# Lab 01: Prometheus Recording Rules and Advanced Alertmanager

**Topic:** Advanced Observability

---

## Overview

As your cluster grows, calculating complex metrics (like the 99th percentile of API latency over the last hour) requires significant CPU and memory. Doing this computation every time a user loads a Grafana dashboard can crash Prometheus.

**Recording Rules** pre-compute these complex expressions in the background and save the result as a new, highly-efficient time series.

---

## 🛠️ Hands-on Tasks

### Task 1: Create a Recording Rule

Imagine calculating the per-second error rate of your API across all instances.

1. **Write the Rule Configuration (`rules.yml`):**
```yaml
groups:
  - name: api_error_rates
    interval: 1m
    rules:
      # The name of the new, pre-computed metric
      - record: job:http_errors:rate5m
        # The complex PromQL query to run in the background
        expr: sum(rate(http_requests_total{status=~"5.."}[5m])) by (job)
```

2. **Load it into Prometheus:**
Ensure your `prometheus.yml` is configured to read the rules file:
```yaml
rule_files:
  - "rules.yml"
```

3. **Use it in Grafana:**
Instead of typing the heavy `sum(rate(...))` query into your Grafana panel, you simply query `job:http_errors:rate5m`. The graph will load instantly.

### Task 2: Advanced Alerting (Routing & Inhibitions)

Alertmanager doesn't just send emails; it deduplicates, groups, and routes alerts based on severity.

1. **Configure `alertmanager.yml`:**
```yaml
route:
  # The default receiver
  receiver: 'slack-general'
  group_by: ['alertname', 'cluster']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

  # Child routes
  routes:
    # If the alert has a label "severity: critical", send it to PagerDuty
    - matchers:
        - severity="critical"
      receiver: 'pagerduty-sre'
    # If the alert is about the database, send to the DB team's Slack
    - matchers:
        - team="database"
      receiver: 'slack-db-team'

# Inhibitions prevent alert storms
inhibit_rules:
  # If a node goes down, it will trigger a "NodeDown" alert.
  # This rule silences all "InstanceDown" or "HighCPU" alerts for that specific node,
  # because we already know the whole node is down!
  - source_matchers:
      - alertname="NodeDown"
    target_matchers:
      - severity="warning"
    equal: ['instance']

receivers:
  - name: 'slack-general'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/...'
  - name: 'pagerduty-sre'
    pagerduty_configs:
      - service_key: '<your-key>'
```

---

## ✅ Best Practices
- **Naming Conventions:** Recording rules should follow the standard `level:metric:operations` format (e.g., `cluster:node_cpu:sum_rate5m`).
- **Use Inhibitions:** A single network switch failure can trigger 10,000 "Service Unreachable" alerts. Use Alertmanager's `inhibit_rules` to suppress downstream noise when a core dependency fails.

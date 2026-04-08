# Monitoring Guide

Complete reference for the monitoring and observability stack.

---

## Table of Contents

- [Overview](#overview)
- [Components](#components)
- [Architecture](#architecture)
- [Prometheus](#prometheus)
- [Grafana](#grafana)
- [Loki (Logging)](#loki-logging)
- [Alerting](#alerting)
- [Dashboards](#dashboards)
- [Common Operations](#common-operations)
- [Best Practices](#best-practices)

---

## Overview

The monitoring stack provides full observability across the infrastructure:

| Component | Purpose | Port |
|-----------|---------|------|
| **Prometheus** | Metrics collection & storage | 9090 |
| **Grafana** | Visualization & dashboards | 3000 |
| **Loki** | Log aggregation | 3100 |
| **Promtail** | Log shipper (pushes logs to Loki) | N/A |
| **Alertmanager** | Alert routing & notification | 9093 |
| **Node Exporter** | Hardware/OS metrics | 9100 |
| **cAdvisor** | Container metrics | 4194 |

---

## Components

### Prometheus

Time-series database for metrics collection.

**Configuration:** `monitoring/prometheus/prometheus.yml`

**Key scrape targets:**

| Target | Metrics | Description |
|--------|---------|-------------|
| `prometheus:9090` | `prometheus_*` | Prometheus self-monitoring |
| `node-exporter:9100` | `node_*` | CPU, memory, disk, network |
| `cadvisor:4194` | `container_*` | Container resource usage |
| `app:3000` | Application metrics | Custom `/metrics` endpoint |

### Grafana

Dashboard and visualization platform.

**Default credentials:** `admin` / `admin` (change immediately in production!)

**Pre-configured data sources:**
- Prometheus (metrics)
- Loki (logs)

### Loki

Log aggregation system, designed to be cost-effective and horizontally scalable.

**Unlike ELK, Loki:**
- Does not index log content (only labels)
- Stores compressed chunks in object storage
- Integrates natively with Grafana for log querying (LogQL)

### Promtail

Agent that ships logs from containers to Loki.

**Configuration:** `monitoring/promtail/promtail-config.yml`

---

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  App Pods   │────>│  Prometheus  │────>│  Grafana    │
│  (metrics)  │     │  (scrape)    │     │  (dashboards)│
└─────────────┘     └──────────────┘     └─────────────┘
       │                                        ^
       │                                        │
       ▼                                        │
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Promtail   │────>│  Loki        │     │  Alertmanager│
│  (ship logs)│     │  (store logs)│────>│  (route alerts)
└─────────────┘     └──────────────┘     └─────────────┘
                                                │
                                          ┌─────▼─────┐
                                          │  Slack /   │
                                          │  PagerDuty │
                                          └───────────┘
```

---

## Prometheus

### Configuration

```yaml
# monitoring/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:4194']

  - job_name: 'application'
    static_configs:
      - targets: ['app:3000']
    metrics_path: '/metrics'
```

### Useful PromQL Queries

| Metric | Query |
|--------|-------|
| CPU usage % | `100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` |
| Memory usage % | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` |
| Disk usage % | `(1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100` |
| Container memory | `container_memory_usage_bytes{namespace="application"}` |
| Request rate | `rate(http_requests_total[5m])` |
| Error rate | `rate(http_requests_total{status=~"5.."}[5m])` |
| p95 latency | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` |

---

## Grafana

### Access

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/grafana 3001:3000

# Open in browser
open http://localhost:3001
```

### Pre-configured Dashboards

| Dashboard | Description |
|-----------|-------------|
| Node Exporter Full | System-level metrics (CPU, RAM, disk, network) |
| Kubernetes Cluster | Cluster-wide resource utilization |
| Kubernetes Pods | Per-pod resource usage |
| Application | Custom application metrics |
| Loki Logs | Log exploration with LogQL |

### Adding a New Dashboard

1. Open Grafana → Create → Dashboard
2. Add panel with PromQL or LogQL query
3. Save dashboard to the "Infrastructure" folder
4. Export as JSON for version control:
   ```bash
   # Export dashboard
   curl -s http://admin:admin@localhost:3001/api/dashboards/uid/<uid> \
     > monitoring/grafana/dashboards/my-dashboard.json
   ```

---

## Loki (Logging)

### Deploy Loki

```bash
kubectl apply -f monitoring/loki/
kubectl apply -f monitoring/promtail/
```

### Query Logs with LogQL

```logql
# All logs from the application namespace
{namespace="application"}

# Filter by container name
{container="app"} |= "error"

# Log rate over time
rate({container="app"} |= "error" [5m])

# Extract JSON fields from structured logs
{container="app"} | json | status_code >= 500
```

---

## Alerting

### Alert Rules

Alert rules are defined in `monitoring/prometheus/alerts.yml`:

```yaml
groups:
  - name: infrastructure
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 5 minutes."

      - alert: HighMemoryUsage
        expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"

      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) * 60 * 15 > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod {{ $labels.pod }} is crash looping"

      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High 5xx error rate: {{ $value | humanizePercentage }}"
```

### Alertmanager Configuration

```yaml
# monitoring/alertmanager/alertmanager.yml
route:
  receiver: slack
  group_by: [alertname, severity]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: slack
    slack_configs:
      - api_url: 'SLACK_WEBHOOK_URL'
        channel: '#infra-alerts'
        send_resolved: true
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ end }}'
```

---

## Common Operations

### Deploy Monitoring Stack

```bash
# All at once
kubectl apply -f monitoring/

# Individual components
kubectl apply -f monitoring/prometheus/
kubectl apply -f monitoring/grafana/
kubectl apply -f monitoring/loki/
kubectl apply -f monitoring/promtail/
kubectl apply -f monitoring/alertmanager/
```

### Check Status

```bash
kubectl get all -n monitoring

# Verify Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090/targets
```

### Access Components

| Component | Command | URL |
|-----------|---------|-----|
| Grafana | `kubectl port-forward -n monitoring svc/grafana 3001:3000` | http://localhost:3001 |
| Prometheus | `kubectl port-forward -n monitoring svc/prometheus 9090:9090` | http://localhost:9090 |
| Loki | `kubectl port-forward -n monitoring svc/loki 3100:3100` | http://localhost:3100 |

---

## Best Practices

1. **Change Grafana admin password** — immediately after first login
2. **Set appropriate scrape intervals** — 15s for most metrics, 60s for slow-changing ones
3. **Use recording rules** — pre-compute expensive PromQL queries
4. **Alert on symptoms, not causes** — "high error rate" > "CPU high"
5. **Avoid alert fatigue** — use `for` durations, group alerts, set appropriate severity
6. **Retain metrics appropriately** — use remote storage (Thanos, Cortex) for long-term retention
7. **Monitor the monitor** — alert on Prometheus being down
8. **Use labels consistently** — `environment`, `service`, `team` labels on all metrics
9. **Version-control dashboards** — export and commit Grafana dashboard JSON
10. **Test alerting** — use `alertmanager-test` or fire test alerts regularly

# Grafana Metrics Guide

Quick reference for finding SLI, SLO, error budgets, and load test metrics in Grafana.

## 🎯 Quick Start (TL;DR)

1. **Port-forward Grafana**: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80`
2. **Login**: http://localhost:3000 (admin/prom-operator)
3. **View Load Test Impact**: 
   - Go to **Dashboards** → **Kubernetes / Compute Resources / Pod**
   - Select namespace: `tickets-dev`
   - Choose backend/frontend pods
   - Look for CPU/memory/network spikes during load test window (2025-01-20 10:00-10:09 UTC)

**Expected Metrics During Load Test**:
- CPU usage spike: 20-40% increase
- Memory usage: Gradual increase then stabilize
- Network I/O: Significant spike (50-100 MB/s+)
- Pod restarts: Should remain 0

---

## 📊 Finding Your Metrics in Grafana

### Option 1: Explore Built-in Dashboards

1. **Log into Grafana** → http://localhost:3000

2. **Navigate to Dashboards**:
   - Click the **☰** menu (top left)
   - Click **Dashboards**
   - You'll see pre-installed kube-prometheus-stack dashboards

3. **Key Dashboards to Check**:

   **a) Kubernetes / Compute Resources / Namespace (Pods)**
   - Select namespace: `tickets-dev`
   - Shows CPU, Memory, Network for your backend/frontend pods
   - **Load Test Impact**: You'll see spikes during the stress test

   **b) Kubernetes / Compute Resources / Pod**
   - Select pod: `backend-*` or `frontend-*`
   - Detailed resource usage per pod
   - CPU throttling, memory, network I/O

   **c) Node Exporter / USE Method / Node**
   - Shows EKS node metrics
   - Utilization, Saturation, Errors

---

### Option 2: Query Prometheus Directly in Grafana

Since we applied custom SLI/SLO recording rules, you can query them directly:

#### **Step 1: Open Explore**
- Click **Explore** (compass icon) in left sidebar
- Or go to: http://localhost:3000/explore

#### **Step 2: Query SLI Metrics**

**SLI Query Examples** (paste these into the query box):

```promql
# 1. REQUEST RATE (Traffic)
job:http_requests_total:rate5m

# 2. ERROR RATE (Errors) 
job:http_requests_5xx:rate5m

# 3. AVAILABILITY (1 - error rate)
job:availability_ratio:5m

# 4. P95 LATENCY (Latency)
job:latency_p95:5m

# 5. P99 LATENCY
job:latency_p99:5m

# 6. REQUEST RATE PER ENDPOINT
endpoint:http_requests_total:rate1m

# 7. ERROR RATE PER ENDPOINT
endpoint:http_errors_total:rate1m
```

#### **Step 3: Visualize SLO Compliance**

**Availability SLO** (Target: 99.9%):
```promql
# Current availability
job:availability_ratio:5m * 100

# SLO target line (add as second query)
99.9
```

**Latency SLO** (Target: p95 < 800ms):
```promql
# Current p95 latency (in seconds)
job:latency_p95:5m

# SLO target line (add as second query)
0.8
```

**Error Budget Remaining**:
```promql
# Error budget consumption (%)
(1 - job:availability_ratio:5m) / 0.001 * 100

# 100% = all budget consumed, 0% = no budget used
```

---

### Option 3: Create Custom SLO Dashboard

Let me create a dashboard JSON for you to import:

#### **Import Custom Dashboard**

1. Click **☰** → **Dashboards** → **New** → **Import**
2. Paste the JSON below
3. Click **Load**
4. Select Prometheus data source
5. Click **Import**

---

## 📈 How to Find Load Test Metrics

### During/After K6 Load Test

The metrics you want to see are:

#### **1. Traffic (Request Rate)**

**Query**:
```promql
rate(http_requests_total{namespace="tickets-dev"}[1m])
```

**What to look for**:
- Baseline: ~6 req/s during happy path test
- Spike: ~86 req/s during stress test
- You should see clear spikes during 10:00-10:09 UTC

#### **2. Latency (Response Time)**

**Query**:
```promql
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket{namespace="tickets-dev"}[5m])) by (le)
)
```

**What to look for**:
- Should stay below 800ms (0.8s) - your SLO
- During stress test: ~111ms (excellent!)

#### **3. Errors (5xx Rate)**

**Query**:
```promql
rate(http_requests_total{namespace="tickets-dev", status=~"5.."}[5m])
```

**What to look for**:
- Should be near zero
- Spikes indicate backend errors

#### **4. Saturation (Resource Usage)**

**Pod CPU**:
```promql
sum(rate(container_cpu_usage_seconds_total{namespace="tickets-dev", pod=~"backend.*"}[5m])) by (pod)
```

**Pod Memory**:
```promql
sum(container_memory_working_set_bytes{namespace="tickets-dev", pod=~"backend.*"}) by (pod)
```

**What to look for**:
- CPU spikes during load test
- Memory should be stable (no leaks)

---

## 🎯 Creating Your SLO Dashboard

### Quick Import Dashboard JSON

Save this as `slo-dashboard.json` and import it:

```json
{
  "dashboard": {
    "title": "AegisTickets SLO Dashboard",
    "panels": [
      {
        "title": "Availability (SLO: 99.9%)",
        "targets": [
          {
            "expr": "job:availability_ratio:5m * 100",
            "legendFormat": "Current Availability %"
          },
          {
            "expr": "99.9",
            "legendFormat": "SLO Target"
          }
        ],
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "title": "Latency p95 (SLO: 800ms)",
        "targets": [
          {
            "expr": "job:latency_p95:5m * 1000",
            "legendFormat": "p95 Latency (ms)"
          },
          {
            "expr": "800",
            "legendFormat": "SLO Target"
          }
        ],
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "job:http_requests_total:rate5m",
            "legendFormat": "{{job}}"
          }
        ],
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "title": "Error Budget Burn Rate",
        "targets": [
          {
            "expr": "(1 - job:availability_ratio:5m) / 0.001 * 100",
            "legendFormat": "Budget Consumed %"
          }
        ],
        "type": "gauge",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ]
  }
}
```

---

## 🔍 Troubleshooting: "No Data" in Grafana

If you see "No Data" for SLI metrics, it's because your **application isn't exporting Prometheus metrics yet**.

### Why?

The K6 load test generates traffic, but the metrics need to come from:
1. **Backend application** - instrumented with prometheus_client
2. **Kubernetes metrics** - from kube-state-metrics

### Solution: Check if Backend is Exposing Metrics

```bash
# Test if backend exposes /metrics endpoint
curl http://k8s-ticketsd-ticketsi-af8913317e-175346924.eu-west-1.elb.amazonaws.com/api/metrics

# Or check directly on the pod
kubectl exec -n tickets-dev backend-6d6f54ff5b-86vfm -- curl localhost:8000/metrics
```

### Fallback: Use Kubernetes Metrics

Even without app metrics, you can see:

**Pod CPU Usage**:
```promql
sum(rate(container_cpu_usage_seconds_total{namespace="tickets-dev"}[5m])) by (pod)
```

**Pod Memory**:
```promql
container_memory_working_set_bytes{namespace="tickets-dev"}
```

**Network Traffic**:
```promql
rate(container_network_receive_bytes_total{namespace="tickets-dev"}[5m])
```

---

## 📊 Pre-Built Dashboards You Already Have

Navigate to **Dashboards** and look for:

### 1. **Kubernetes / Compute Resources / Namespace (Pods)**
- **What it shows**: CPU, Memory, Network per pod in tickets-dev
- **Load Test**: You'll see spikes around 10:00-10:09 UTC
- **Path**: Dashboards → Browse → "Kubernetes / Compute Resources"

### 2. **Kubernetes / Compute Resources / Pod**
- **What it shows**: Detailed single-pod metrics
- **Good for**: Analyzing backend-* or frontend-* performance

### 3. **Node Exporter Full**
- **What it shows**: EKS node metrics (CPU, disk, network)
- **Load Test**: Shows node-level impact of 100 concurrent users

### 4. **Prometheus Stats**
- **What it shows**: Prometheus scrape health
- **Check**: If Prometheus is successfully scraping targets

---

## 🎯 What You Should See (Expected Results)

### Time Range: 09:55 - 10:15 UTC (Oct 20, 2025)

#### **CPU Usage (Backend Pods)**
```
Baseline: ~50-100m (5-10% of 1 core)
Happy Test (10:00): ~150-200m
Stress Test (10:02-10:09): ~300-500m
Post-test: Back to ~50m
```

#### **Memory Usage (Backend Pods)**
```
Steady: ~150-200 MB (no memory leaks)
```

#### **Network Ingress (Backend)**
```
Baseline: ~1-2 KB/s
Happy Test: ~10-20 KB/s
Stress Test: ~100-150 KB/s
```

#### **Request Rate (if metrics available)**
```
Baseline: 0 req/s
Happy Test: ~6 req/s
Stress Test: ~86 req/s
```

---

## 🚀 Quick Commands to Verify

```bash
# 1. Check if Grafana is accessible
curl http://localhost:3000/api/health

# 2. Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Then visit: http://localhost:9090/targets

# 3. Check if ServiceMonitor is discovering pods
kubectl get servicemonitor -n tickets-dev

# 4. Check backend metrics endpoint
kubectl exec -n tickets-dev backend-6d6f54ff5b-86vfm -- wget -qO- localhost:8000/metrics | head -20
```

---

## 📌 Summary: Where to Find Your Data

| Metric Type | Best Dashboard | Alternative Query |
|-------------|---------------|-------------------|
| **CPU/Memory** | Kubernetes / Compute Resources / Namespace (Pods) | `container_cpu_usage_seconds_total` |
| **Network** | Kubernetes / Compute Resources / Pod | `container_network_receive_bytes_total` |
| **Pod Count** | Kubernetes / Compute Resources / Cluster | `kube_pod_status_phase` |
| **SLIs** | Create custom (import JSON above) | `job:availability_ratio:5m` |
| **Load Test Impact** | Kubernetes / Compute Resources (time: 10:00-10:09) | Filter by namespace=tickets-dev |

---

## 🎨 Next Steps

1. **Import the SLO Dashboard JSON** (see above)
2. **Set time range** to 09:55 - 10:15 UTC to see load test
3. **Check "Kubernetes / Compute Resources / Namespace (Pods)"** dashboard
4. **Query Prometheus** for SLI metrics using the examples above
5. **Create alerts** based on SLO breaches

---

**Need Help?**
- Grafana Docs: https://grafana.com/docs/grafana/latest/
- Prometheus Query Examples: https://prometheus.io/docs/prometheus/latest/querying/examples/
- PromQL Cheat Sheet: https://promlabs.com/promql-cheat-sheet/

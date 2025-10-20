# Service Level Objectives (SLOs)

## Overview

AegisTickets operates under strict SLOs to ensure reliable ticketing services during critical on-sale windows. This document defines our measurable reliability targets.

## Measurement Window

All SLOs are measured over a **28-day rolling window** unless otherwise stated.

---

## 1. Availability SLO

### Objective
**≥ 99.9% availability** for API endpoints

### Definition
- **Success**: HTTP status codes 200-499 (excluding 429)
- **Failure**: HTTP status codes 500-599

### Calculation
```
Availability = (Total Requests - 5xx Errors) / Total Requests
```

### Error Budget
- **Target**: 99.9% (three nines)
- **Allowed downtime**: ~40 minutes per 28 days
- **Error budget**: 0.1% of requests can fail

### PromQL Query
```promql
# Recording rule
job:availability_ratio:5m = 1 - (
  job:http_requests_5xx:rate5m
  /
  job:http_requests_total:rate5m
)
```

### SLI Implementation
Tracked via:
- `http_requests_total` counter (labeled by status code)
- `http_requests_5xx:rate5m` recording rule
- Dashboard: **SLO Overview** → Availability panel

---

## 2. Latency SLO

### Objective
**p95 latency ≤ 800ms** during business hours (09:00–21:00 Europe/London)

### Definition
- 95% of requests must complete within 800ms
- Measured at the backend service level
- Includes database query time

### Calculation
```
p95_latency = histogram_quantile(0.95, http_request_latency_seconds_bucket)
```

### Error Budget
- Sustained p95 > 800ms for >15 minutes constitutes SLO breach
- Advisory target: p99 ≤ 1.5s

### PromQL Query
```promql
# Recording rule
job:latency_p95:5m = histogram_quantile(0.95,
  sum by (le, job) (rate(http_request_latency_seconds_bucket[5m]))
)
```

### SLI Implementation
Tracked via:
- `http_request_latency_seconds` histogram (buckets: 0.1, 0.25, 0.5, 0.8, 1.0, 1.5, 2.0, 5.0)
- Dashboard: **Golden Signals** → Latency heatmap

---

## 3. Saturation SLO (Database)

### Objective
**Active DB connections ≤ 80% of pool** for ≥99% of 5-minute measurement windows

### Definition
- Each backend pod has a connection pool (default: 20)
- Total pool = replicas × pool_size_per_pod
- Saturation measured every 5 minutes

### Calculation
```
saturation = active_connections / max_connections
```

### Error Budget
- Breaching 80% threshold for >5 minutes in a 28-day period counts against budget
- Allowed: <1% of measurement windows can exceed 80%

### PromQL Query
```promql
# Saturation gauge
(db_active_connections / 100) > 0.8
```

### SLI Implementation
Tracked via:
- `db_active_connections` gauge (exposed by backend)
- Dashboard: **Golden Signals** → DB Saturation panel

---

## 4. Frontend Performance (Advisory)

### Objective
**p95 Largest Contentful Paint (LCP) ≤ 1.2s**

### Definition
- Measured via Real User Monitoring (RUM) if implemented
- Advisory: not included in primary error budget calculations
- Target: "Good" Core Web Vitals

### Future Implementation
- Google Analytics or similar RUM tool
- Client-side performance API
- Separate dashboard for frontend metrics

---

## SLO Summary Table

| **SLO** | **Target** | **Window** | **Error Budget** | **Alert Threshold** |
|---------|-----------|-----------|-----------------|-------------------|
| Availability | ≥99.9% | 28 days | ~40 min downtime | Fast burn: >1% error rate for 10min |
| Latency (p95) | ≤800ms | Business hours | 15min sustained breach | p95 >800ms for 15min |
| DB Saturation | ≤80% | 5min windows | <1% of windows | >80% for 5min |
| Frontend LCP | ≤1.2s | Advisory | N/A | Advisory only |

---

## Alerting Strategy

### Fast Burn Alerts (Critical)
- **Trigger**: Availability drops below 99% in 5-min window (>1% error rate)
- **For**: 10 minutes
- **Action**: Immediate investigation, potential rollback

### Slow Burn Alerts (Major)
- **Trigger**: Availability below 99.9% in 1-hour window
- **For**: 1 hour
- **Action**: Review error budget, investigate root cause

### Latency Breach (High)
- **Trigger**: p95 latency >800ms
- **For**: 15 minutes
- **Action**: Check HPA, DB pool, recent deployments

---

## Compliance & Review

- **Review Frequency**: Weekly SLO review meeting
- **Dashboard**: [Grafana SLO Overview](http://localhost:3000) (port-forward)
- **Ownership**: SRE team + Product
- **Adjustment Process**: Quarterly SLO revision based on business needs

---

## Related Documents
- [Error Budgets](./error-budgets.md)
- [Runbooks](./runbooks.md)
- [Architecture](./architecture.md)

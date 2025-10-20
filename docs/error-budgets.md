# Error Budget Policy

## Philosophy

Error budgets provide a quantitative measure of how much unreliability is acceptable. They create alignment between product velocity and reliability, answering: **"How much can we afford to break things?"**

---

## Error Budget Calculation

### Availability Error Budget

**Target SLO**: 99.9% availability over 28 days

```
Total time in 28 days = 28 × 24 × 60 = 40,320 minutes
Error budget = (1 - 0.999) × 40,320 = 40.32 minutes
```

**Allowed downtime**: ~40 minutes per 28 days

### Budget Tracking
```
Remaining budget = 40.32 min - (actual_downtime_minutes)
Budget health = (remaining_budget / 40.32) × 100%
```

---

## Burn Rate

Burn rate measures how quickly we're consuming error budget.

### Fast Burn
- **Definition**: Error budget consumed 6x faster than expected
- **Example**: If error rate is sustained, budget exhausted in ~4.7 days instead of 28
- **Alert**: `SLOAvailabilityFastBurn`

### Slow Burn
- **Definition**: Error budget consumed 3x faster than expected
- **Example**: Budget exhausted in ~9.3 days
- **Alert**: `SLOAvailabilitySlowBurn`

### PromQL for Burn Rate
```promql
# 1-hour burn rate (fraction of budget consumed per hour)
burn_rate_1h = (
  1 - avg_over_time(job:availability_ratio:5m[1h])
) / 0.001  # 0.001 = hourly budget (0.1% / 28d / 24h)
```

---

## Error Budget Thresholds & Actions

| **Budget Remaining** | **Status** | **Action** |
|---------------------|-----------|-----------|
| 75–100% | 🟢 Healthy | Normal development velocity. Deploy features, take calculated risks. |
| 50–75% | 🟡 Caution | Review recent changes. Consider slower release cadence. |
| 25–50% | 🟠 Warning | **Deployment freeze** for non-critical features. Focus on stability. |
| 0–25% | 🔴 Critical | **Full deployment freeze**. Only critical bug fixes and rollbacks allowed. Incident review required. |
| <0% (exhausted) | 🚨 Emergency | **All deployments halted**. Postmortem mandatory. SLO may need adjustment. |

---

## Policy Enforcement

### 1. Daily Budget Check
```bash
# Example query for budget remaining
remaining_pct = (
  (40.32 - sum_over_time(downtime_minutes[28d]))
  / 40.32
) * 100
```

### 2. Automated Gates
- CI/CD pipeline checks error budget before production deploy
- If budget <25%, deployment blocked (override requires approval)

### 3. Weekly SLO Review
- **Attendees**: SRE, Engineering, Product
- **Agenda**:
  - Current budget status
  - Recent incidents and budget impact
  - Forecast: will we exhaust budget before window ends?
  - Action items

---

## Budget Spending Guidelines

### Allowed Spending
✅ **Acceptable uses** of error budget:
- Planned maintenance windows (communicated)
- Canary deployments with quick rollback
- Load testing that may cause transient errors
- Rolling updates with brief downtime per pod

### Unacceptable Spending
❌ **Not acceptable**:
- Unplanned outages due to poor testing
- Repeated incidents from same root cause
- Ignoring alerts leading to prolonged downtime

---

## Budget Reset & Adjustment

### Rolling Window Reset
- Budget is calculated over a **28-day rolling window**
- Old incidents "age out" after 28 days
- No manual reset needed

### SLO Adjustment
- If budget consistently exhausted: SLO may be too aggressive
- If budget never consumed: SLO may be too lenient
- **Review quarterly** with stakeholders

---

## Incident Response & Budget

### Post-Incident
1. **Quantify impact**: How many minutes of budget consumed?
2. **Root cause**: What caused the incident?
3. **Corrective actions**: Prevent recurrence (error budget investment)
4. **Update runbook**: Document mitigation steps

### Budget Borrowing
- Not permitted
- If critical feature requires risk-taking when budget low, requires VP/CTO approval

---

## Example Budget Scenario

### Week 1
- **Incident**: Database connection pool saturation → 5 minutes downtime
- **Budget consumed**: 5 / 40.32 = 12.4%
- **Remaining**: 87.6%
- **Status**: 🟢 Healthy

### Week 2
- **Deploy**: New feature causes 2% error rate for 20 minutes
- **Budget consumed**: 20 × 0.02 = 0.4 min
- **Remaining**: 87.6% - 1% = 86.6%
- **Status**: 🟢 Healthy

### Week 3
- **Incident**: Bad deploy → rolled back after 30 minutes, 10% error rate
- **Budget consumed**: 30 × 0.10 = 3 min
- **Remaining**: 86.6% - 7.4% = 79.2%
- **Status**: 🟢 Healthy (approaching caution)

### Week 4
- **Incident**: Infrastructure issue → 15 min total outage
- **Budget consumed**: 15 min
- **Remaining**: 79.2% - 37.2% = 42%
- **Status**: 🟠 **WARNING** → Deployment freeze for non-critical changes

---

## Monitoring & Dashboards

### Grafana Dashboard: "Error Budget Health"
**Panels**:
1. **Budget Remaining (%)**: Gauge showing current budget health
2. **Burn Rate (1h, 6h, 24h)**: Line chart
3. **Budget Consumption Timeline**: Bar chart of incidents
4. **Projected Budget Exhaustion**: Forecast based on current burn rate

### Prometheus Queries
```promql
# Budget remaining (minutes)
40.32 - sum_over_time(downtime_minutes[28d])

# Budget health percentage
(40.32 - sum_over_time(downtime_minutes[28d])) / 40.32 * 100
```

---

## Escalation Path

1. **Budget < 50%**: Email notification to SRE + Engineering leads
2. **Budget < 25%**: Slack alert + deployment freeze
3. **Budget < 10%**: Page on-call + executive notification
4. **Budget exhausted**: Mandatory postmortem + CTO review

---

## Related Documents
- [SLOs](./slos.md)
- [Runbooks](./runbooks.md)
- [Architecture](./architecture.md)

# Operational Runbooks

## Table of Contents
1. [Latency Breach (p95 > 800ms)](#1-latency-breach)
2. [Availability Fast Burn](#2-availability-fast-burn)
3. [Database Saturation](#3-database-saturation)
4. [Pod Crash Loop](#4-pod-crash-loop)
5. [Deployment Rollback](#5-deployment-rollback)

---

## 1. Latency Breach (p95 > 800ms for 15min)

### Alert
**Name**: `LatencyP95Breaching`  
**Severity**: High  
**Threshold**: p95 latency >800ms for 15 minutes

### Symptoms
- Users report slow page loads
- Backend response times elevated
- Possible timeout errors

### Investigation Steps

#### Step 1: Check Current Metrics
```bash
# Port-forward to Grafana
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

# Open: http://localhost:3000
# Dashboard: "Golden Signals" → Latency panel
```

#### Step 2: Check HPA Status
```bash
# Check if backend is scaling
kubectl -n tickets-dev get hpa

# Check pod CPU/memory usage
kubectl -n tickets-dev top pods

# Check for CPU throttling
kubectl -n tickets-dev describe hpa backend
```

#### Step 3: Database Connection Pool
```bash
# Check DB connection gauge from Prometheus
# Query: db_active_connections

# If near limit, check DB instance CPU
# AWS Console → RDS → Performance Insights
```

#### Step 4: Recent Deployments
```bash
# Check recent deployment history
kubectl -n tickets-dev rollout history deployment/backend

# Get current image tag
kubectl -n tickets-dev get deployment backend -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Resolution Actions

#### If CPU-bound:
```bash
# Manually scale up
kubectl -n tickets-dev scale deployment backend --replicas=5

# Or adjust HPA targets
kubectl -n tickets-dev edit hpa backend
# Lower targetCPUUtilizationPercentage from 70 to 60
```

#### If DB pool saturated:
```bash
# Scale backend to increase total pool
kubectl -n tickets-dev scale deployment backend --replicas=4

# OR upgrade RDS instance (Terraform)
# Edit infra/envs/dev/main.tf
# instance_class = "db.t4g.small"  # from db.t4g.micro
```

#### If deploy-correlated:
See [Deployment Rollback](#5-deployment-rollback)

### Post-Incident
- **Document**: Screenshot of latency spike in Grafana
- **Root cause**: Identify trigger (deploy, load spike, DB issue)
- **Error budget**: Calculate minutes of SLO breach
- **Follow-up**: Update HPA or DB sizing if needed

---

## 2. Availability Fast Burn (5xx rate >1% for 10min)

### Alert
**Name**: `SLOAvailabilityFastBurn`  
**Severity**: Critical  
**Threshold**: Error rate >1% for 10 minutes

### Symptoms
- Users see 500/502/503 errors
- Error budget burning rapidly
- May indicate total outage

### Investigation Steps

#### Step 1: Check Error Rate
```bash
# Grafana → "SLO Overview" dashboard
# Or Prometheus query:
# rate(http_requests_total{code=~"5.."}[5m]) / rate(http_requests_total[5m])
```

#### Step 2: Backend Pod Status
```bash
# Check pod health
kubectl -n tickets-dev get pods

# Check pod logs (recent errors)
kubectl -n tickets-dev logs -l app=backend --tail=100 --prefix

# Check events
kubectl -n tickets-dev get events --sort-by='.lastTimestamp'
```

#### Step 3: Database Connectivity
```bash
# Test DB readiness from a backend pod
kubectl -n tickets-dev exec -it deployment/backend -- curl http://localhost:8000/readiness

# Check RDS status in AWS Console
# RDS → tickets-dev-db → Monitoring tab
```

#### Step 4: ALB Health
```bash
# Check ALB target health
# AWS Console → EC2 → Load Balancers → Target Groups
# Look for unhealthy targets
```

### Resolution Actions

#### If pods crashlooping:
```bash
# Check recent config changes
kubectl -n tickets-dev get configmap
kubectl -n tickets-dev get secret

# Rollback deployment
kubectl -n tickets-dev rollout undo deployment/backend
```

#### If database down:
```bash
# Check RDS endpoint
aws rds describe-db-instances --db-instance-identifier tickets-dev-db --query 'DBInstances[0].DBInstanceStatus'

# If stopped, start it
aws rds start-db-instance --db-instance-identifier tickets-dev-db
```

#### If bad deployment:
See [Deployment Rollback](#5-deployment-rollback)

### Post-Incident
- **Quantify impact**: Total downtime minutes, % of requests affected
- **Budget burn**: Update error budget tracking
- **Postmortem**: Required for >10min outages
- **Communication**: Notify stakeholders

---

## 3. Database Saturation (connections >80% for 5min)

### Alert
**Name**: `DatabaseConnectionSaturation`  
**Severity**: Warning  
**Threshold**: >80% of max connections for 5 minutes

### Symptoms
- Backend logs show "connection pool exhausted"
- Intermittent 500 errors under load
- Slow queries pile up

### Investigation Steps

#### Step 1: Current Connection Count
```bash
# Prometheus query: db_active_connections
# Expected max: replicas × pool_size (e.g., 2 × 20 = 40)
```

#### Step 2: Check Backend Replicas
```bash
kubectl -n tickets-dev get deployment backend -o jsonpath='{.spec.replicas}'
```

#### Step 3: RDS Performance Insights
```bash
# AWS Console → RDS → tickets-dev-db → Performance Insights
# Check:
# - DB connections count
# - Active sessions
# - Top SQL queries
```

### Resolution Actions

#### Short-term: Scale Backend
```bash
# Increase replicas (increases total pool)
kubectl -n tickets-dev scale deployment backend --replicas=4

# Verify saturation drops
# Watch Prometheus: db_active_connections
```

#### Medium-term: Tune Connection Pool
```python
# In app/backend/app.py, adjust pool size (default 20)
# Or set via environment variable

# Update Helm values:
# deploy/helm/backend/values-dev.yaml
env:
  - name: DB_POOL_SIZE
    value: "30"
```

#### Long-term: Upgrade RDS
```bash
# Edit infra/envs/dev/main.tf
instance_class = "db.t4g.medium"  # More CPU, higher connection limit

# Apply Terraform
cd infra/envs/dev
terraform apply -target=module.rds
```

### Prevention
- **Monitoring**: Set up CloudWatch alarm for RDS connections
- **Load testing**: Run k6 scenarios to validate pool sizing
- **Auto-scaling**: Ensure HPA triggers before saturation

---

## 4. Pod Crash Loop

### Alert
**Name**: `PodCrashLooping`  
**Severity**: Warning  
**Threshold**: Container restart rate >0 for 5 minutes

### Investigation Steps

#### Step 1: Identify Failing Pods
```bash
kubectl -n tickets-dev get pods
# Look for RESTARTS column >0
```

#### Step 2: Check Logs
```bash
# Get logs from crashed container
kubectl -n tickets-dev logs <pod-name> --previous

# If multiple restarts, check current logs
kubectl -n tickets-dev logs <pod-name> --tail=50
```

#### Step 3: Describe Pod
```bash
kubectl -n tickets-dev describe pod <pod-name>
# Look at Events section for failure reason
```

### Common Causes & Fixes

#### OOMKilled (Out of Memory)
```bash
# Increase memory limit
kubectl -n tickets-dev edit deployment backend
# spec.template.spec.containers[0].resources.limits.memory: "512Mi"
```

#### CrashLoopBackOff (App Error)
```bash
# Check environment variables
kubectl -n tickets-dev get deployment backend -o yaml | grep -A 10 env

# Verify secret exists
kubectl -n tickets-dev get secret backend-db
```

#### ImagePullBackOff
```bash
# Check image name
kubectl -n tickets-dev describe pod <pod-name> | grep Image

# Verify ECR access (IRSA)
kubectl -n tickets-dev get sa backend -o yaml
```

---

## 5. Deployment Rollback

### When to Rollback
- Error rate spikes after deployment
- p95 latency >800ms sustained
- Critical functionality broken
- **Error budget <25% and incident ongoing**

### Rollback Procedure

#### Option A: Helm Rollback (Recommended)
```bash
# List release history
helm history backend -n tickets-dev

# Rollback to previous revision
helm rollback backend -n tickets-dev

# Or rollback to specific revision
helm rollback backend 3 -n tickets-dev
```

#### Option B: kubectl Rollback
```bash
# Rollback deployment
kubectl -n tickets-dev rollout undo deployment/backend

# Check rollback status
kubectl -n tickets-dev rollout status deployment/backend
```

#### Option C: Redeploy Previous Image
```bash
# Get previous image SHA from Git history
# or ECR console

# Redeploy with old image
helm upgrade backend deploy/helm/backend \
  -n tickets-dev \
  -f deploy/helm/backend/values-dev.yaml \
  --set image.tag=sha-<PREVIOUS_SHA>
```

### Verification
```bash
# Wait for rollout to complete
kubectl -n tickets-dev rollout status deployment/backend

# Check pod health
kubectl -n tickets-dev get pods

# Monitor metrics in Grafana
# - Error rate should drop
# - Latency should normalize

# Verify with test request
curl http://<ALB_DNS>/api/events
```

### Post-Rollback
1. **Notify team**: Deployment rolled back
2. **Root cause**: Review what went wrong
3. **Fix forward**: Address issue before re-deploying
4. **Update runbook**: Add learnings

---

## General Troubleshooting Commands

```bash
# Get ALB DNS
kubectl -n tickets-dev get ingress tickets-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Check all resources
kubectl -n tickets-dev get all

# Get Prometheus targets
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# Open: http://localhost:9090/targets

# View logs from all backend pods
kubectl -n tickets-dev logs -l app=backend --tail=50 --prefix

# Execute command in pod
kubectl -n tickets-dev exec -it deployment/backend -- /bin/sh

# Port-forward to backend directly
kubectl -n tickets-dev port-forward svc/backend 8000:8000
curl http://localhost:8000/healthz
```

---

## Related Documents
- [SLOs](./slos.md)
- [Error Budgets](./error-budgets.md)
- [Architecture](./architecture.md)

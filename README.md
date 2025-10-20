# AegisTickets-Lite

> Production-grade 3-tier AWS EKS ticketing platform demonstrating Golden Signals, SLIs/SLOs, and Error Budgets

A comprehensive event ticketing application built to showcase SRE best practices, observability-driven development, and production-ready Kubernetes deployments on AWS.

## ✅ Current Deployment Status

**Environment**: Development (eu-west-1)  
**Status**: ✅ Deployed and Load Tested  
**Application URL**: http://k8s-ticketsd-ticketsi-af8913317e-175346924.eu-west-1.elb.amazonaws.com

### Infrastructure
- **EKS Cluster**: tickets-dev (2 m7i-flex.large nodes)
- **RDS PostgreSQL**: tickets-dev-db (db.t3.micro, Multi-AZ)
- **Application**: Backend (2 pods) + Frontend (1 pod) - All healthy
- **Monitoring**: kube-prometheus-stack v67.6.1 (Prometheus + Grafana + Alertmanager)

### SLO Compliance Results
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| **Availability** | ≥99.9% | 99.97% | ✅ Exceeds by 0.07% |
| **P95 Latency** | ≤800ms | 111ms | ✅ 86% better |
| **Error Rate** | <1% | 0.03% | ✅ 97% better |

**Load Test Summary**: Sustained 86 req/s under 100 concurrent users for 7 minutes with zero pod restarts.

📄 See [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md) for full deployment details.  
📄 See [PERFORMANCE_REPORT.md](PERFORMANCE_REPORT.md) for comprehensive performance analysis.  
📄 See [GRAFANA_GUIDE.md](GRAFANA_GUIDE.md) for monitoring dashboard access.

---

## 🎯 Project Objectives

- Implement **Golden Signals** (Latency, Traffic, Errors, Saturation) instrumentation
- Define and monitor **SLIs/SLOs** (99.9% availability, p95 latency ≤800ms)
- Demonstrate **Error Budget** management and policy enforcement
- Showcase production-ready IaC, GitOps, and observability practices

## 📐 Architecture

```
┌─────────────┐
│   Users     │
└──────┬──────┘
       │
    ┌──▼───────────────────────────┐
    │   AWS ALB (Ingress)          │
    └──────┬───────────────────────┘
           │
    ┌──────▼─────────────────┐
    │   Amazon EKS Cluster   │
    │  ┌──────────────────┐  │
    │  │  Frontend Pods   │  │
    │  │  (React + Nginx) │  │
    │  └────────┬─────────┘  │
    │           │            │
    │  ┌────────▼─────────┐  │
    │  │   Backend Pods   │  │
    │  │  (Flask + Prom)  │  │
    │  └────────┬─────────┘  │
    │           │            │
    └───────────┼────────────┘
                │
         ┌──────▼──────┐
         │  RDS Postgres│
         │   (Multi-AZ) │
         └─────────────┘
```

See [docs/architecture.md](docs/architecture.md) for detailed diagrams.

## 🏗️ Technology Stack

| Layer | Technologies |
|-------|-------------|
| **Frontend** | React 18, Vite, Nginx |
| **Backend** | Python 3.12, Flask, Gunicorn, Prometheus Client |
| **Infrastructure** | Terraform, AWS EKS, RDS PostgreSQL, ALB |
| **Orchestration** | Kubernetes 1.28, Helm 3 |
| **Observability** | Prometheus, Grafana, Alertmanager |
| **CI/CD** | GitHub Actions, AWS OIDC |
| **Security** | IRSA, External Secrets Operator, Trivy, CodeQL |

## 📋 Prerequisites

Before deploying, ensure you have:

- [ ] **AWS CLI** (v2.x) configured with appropriate credentials
- [ ] **kubectl** (v1.28+) for Kubernetes management
- [ ] **Helm** (v3.x) for application deployment
- [ ] **Terraform** (v1.6+) for infrastructure provisioning
- [ ] **Docker** for local builds and image management
- [ ] **k6** (optional) for load testing
- [ ] **Git** for version control

### Install Tools

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# k6 (for load testing)
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update && sudo apt-get install k6
```

## 🚀 Quick Start

### Phase 0: Initial Setup

1. **Clone the repository:**
   ```bash
   git clone git@github.com:OluwaTossin/aegistickets-platform.git
   cd aegistickets-platform
   ```

2. **Set up Terraform backend:**
   ```bash
   chmod +x scripts/*.sh
   ./scripts/setup-backend.sh dev
   ```

3. **Configure AWS credentials:**
   ```bash
   aws configure
   # AWS Access Key ID: <your-key>
   # AWS Secret Access Key: <your-secret>
   # Default region: eu-west-1
   ```

### Phase 1: Deploy Infrastructure

Deploy the complete AWS infrastructure (EKS cluster, RDS, networking):

```bash
cd infra/envs/dev
terraform init
terraform plan
terraform apply
```

**Expected outputs:**
- EKS cluster name
- ECR repository URLs
- RDS endpoint
- ALB DNS name

### Phase 2: Configure kubectl

Update kubeconfig to connect to your EKS cluster:

```bash
aws eks update-kubeconfig --name tickets-dev --region eu-west-1
kubectl get nodes  # Verify connectivity
```

### Phase 3: Apply Kubernetes Manifests

Create namespaces, secrets, and monitoring rules:

```bash
kubectl apply -f deploy/manifests/namespace-dev.yaml
kubectl apply -f deploy/manifests/external-secret-dev.yaml
kubectl apply -f deploy/manifests/monitoring/prometheus-rules.yaml
```

### Phase 4: Build and Push Images

Build Docker images and push to ECR:

```bash
# Get ECR URLs from Terraform outputs
ECR_BACKEND=$(cd infra/envs/dev && terraform output -raw ecr_backend_repository_url)
ECR_FRONTEND=$(cd infra/envs/dev && terraform output -raw ecr_frontend_repository_url)

# Login to ECR
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin $(echo $ECR_BACKEND | cut -d'/' -f1)

# Build and push backend
docker build -t $ECR_BACKEND:latest app/backend
docker push $ECR_BACKEND:latest

# Build and push frontend
docker build -t $ECR_FRONTEND:latest app/frontend
docker push $ECR_FRONTEND:latest
```

### Phase 5: Deploy Applications with Helm

Deploy backend and frontend applications:

```bash
# Deploy backend
helm upgrade --install backend deploy/helm/backend \
  -n tickets-dev \
  -f deploy/helm/backend/values-dev.yaml \
  --wait

# Deploy frontend
helm upgrade --install frontend deploy/helm/frontend \
  -n tickets-dev \
  -f deploy/helm/frontend/values-dev.yaml \
  --wait

# Apply ingress
kubectl apply -f deploy/manifests/ingress-dev.yaml
```

### Phase 6: Verify Deployment

```bash
# Check pod status
kubectl -n tickets-dev get pods

# Check services
kubectl -n tickets-dev get svc

# Get ALB DNS
kubectl -n tickets-dev get ingress tickets-ingress
```

Access the application at: `http://<ALB_DNS>`

### Phase 7: Access Grafana

Port-forward Grafana to view dashboards:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Access Grafana at: `http://localhost:3000`
- **Username:** admin
- **Password:** Run `cd infra/envs/dev && terraform output grafana_password`

**Key Dashboards:**
- Golden Signals Dashboard
- SLO Overview
- Kubernetes Cluster Monitoring

### Phase 8: Run Load Tests

Test SLO compliance with k6:

```bash
# Get ALB DNS
ALB_DNS=$(kubectl -n tickets-dev get ingress tickets-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Run happy path test (validates SLOs)
./scripts/run-load-test.sh happy http://$ALB_DNS

# Run stress test
./scripts/run-load-test.sh stress http://$ALB_DNS
```

## 🔧 Automated Deployment

Use the all-in-one deployment script:

```bash
./scripts/deploy.sh dev
```

This script automates all phases above.

## 📊 SLOs and Monitoring

### Service Level Objectives

| SLI | Target | Measurement Window |
|-----|--------|-------------------|
| **Availability** | 99.9% | 28 days |
| **Latency (p95)** | ≤800ms | 5 minutes |
| **DB Saturation** | ≤80% | 5 minutes |

### Error Budget

- **Budget:** ~40 minutes of downtime per 28 days
- **Policy:** See [docs/error-budgets.md](docs/error-budgets.md)

### Alerts

Prometheus alerts fire when:
- **SLOAvailabilityFastBurn:** Error rate >1% for 5 minutes
- **LatencyP95Breaching:** p95 latency >800ms for 10 minutes
- **DatabaseSaturationHigh:** DB connections >80% for 15 minutes

See [docs/runbooks.md](docs/runbooks.md) for response procedures.

## 🧪 Testing

### Unit Tests

```bash
# Backend
cd app/backend
python -m pytest test_app.py

# Frontend
cd app/frontend
npm test
```

### Load Testing

```bash
# Baseline load
./scripts/run-load-test.sh happy http://<ALB_DNS>

# Stress testing
./scripts/run-load-test.sh stress http://<ALB_DNS>
```

## 🔄 CI/CD Pipeline

GitHub Actions workflows automate:

1. **Build & Scan** (`.github/workflows/build-and-scan.yml`)
   - CodeQL SAST
   - Trivy container scanning
   - Multi-arch builds

2. **Deploy** (`.github/workflows/deploy-dev.yml`)
   - Terraform apply
   - Helm deployments
   - Smoke tests

3. **DAST** (`.github/workflows/dast-zap.yml`)
   - OWASP ZAP scanning

### Required GitHub Secrets

Configure in repository settings:

- `AWS_ACCOUNT_ID` - Your AWS account ID
- `AWS_REGION` - Target region (eu-west-1)
- `CLUSTER_NAME_DEV` - EKS cluster name for dev
- `CLUSTER_NAME_PROD` - EKS cluster name for prod

## 📁 Project Structure

```
aegistickets-platform/
├── app/
│   ├── backend/         # Flask API with Prometheus instrumentation
│   └── frontend/        # React SPA
├── deploy/
│   ├── helm/            # Helm charts for backend/frontend
│   └── manifests/       # K8s manifests (namespaces, ingress, monitoring)
├── infra/
│   ├── modules/         # Reusable Terraform modules (ECR, EKS, RDS, etc.)
│   └── envs/            # Environment-specific configs (dev, prod)
├── scripts/             # Utility scripts (deploy, load tests, cleanup)
├── docs/                # Documentation (architecture, SLOs, runbooks)
└── .github/workflows/   # CI/CD pipelines
```

## 🗑️ Cleanup

To destroy all resources:

```bash
./scripts/cleanup.sh dev
```

**Warning:** This will delete all infrastructure including databases. Ensure you have backups.

## 📚 Documentation

- [Architecture Overview](docs/architecture.md) - System design and AWS architecture
- [SLOs and SLIs](docs/slos.md) - Service level objectives and indicators
- [Error Budgets](docs/error-budgets.md) - Error budget policy and governance
- [Runbooks](docs/runbooks.md) - Operational procedures for incidents

## 🎓 Learning Resources

This project demonstrates:

- **Golden Signals:** Latency, Traffic, Errors, Saturation metrics
- **SLI/SLO/SLA:** Service level management patterns
- **Error Budgets:** Balancing reliability and velocity
- **GitOps:** Infrastructure and application as code
- **12-Factor Apps:** Stateless services, config externalization
- **Cloud-Native Security:** IRSA, secrets management, SAST/DAST

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🙋 Support

For issues or questions:
- Review [runbooks](docs/runbooks.md) for operational procedures
- Check [architecture docs](docs/architecture.md) for system design
- Open a GitHub issue for bugs or feature requests

---

**Built with ❤️ to demonstrate production-grade SRE practices on AWS EKS**

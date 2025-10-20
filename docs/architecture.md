# AegisTickets-Lite Architecture

## Overview

AegisTickets-Lite is a production-grade 3-tier application demonstrating observable SRE practices with explicit Golden Signals, SLIs/SLOs, and Error Budgets.

## Architecture Diagram

```mermaid
flowchart LR
%% =========================================================
%% AegisTickets-Lite — AWS EKS 3-tier with SLO/SLA Observability
%% =========================================================

%% ---------- Internet Entry ----------
U[End User<br/>(Browser)]:::ext

%% ---------- AWS Account (eu-west-1) ----------
subgraph AWS[AWS Account — eu-west-1]
direction LR

  %% ----- Networking/VPC -----
  subgraph VPC[Default VPC]
  direction TB

    subgraph PUB[Public Subnets]
    direction TB
      ALB[ALB (Ingress)<br/>(Public DNS)]:::lb
    end

    subgraph PRIV[Private Subnets]
    direction TB

      %% ----- EKS Cluster -----
      subgraph EKS[EKS Cluster]
      direction TB

        OIDC[(OIDC Provider)]:::iam

        %% Controllers/Operators (IRSA)
        ALBC[aws-load-balancer-controller<br/>(IRSA)]:::ctrl
        ESO[External Secrets Operator<br/>(IRSA)]:::ctrl

        %% Observability Stack
        subgraph MON[monitoring namespace]
        direction LR
          PROM[Prometheus]:::obs
          AM[Alertmanager]:::obs
          GRAF[Grafana]:::obs
        end

        %% App Namespace
        subgraph APP[tickets-dev namespace]
        direction TB
          FESVC[Service: frontend (ClusterIP)]:::svc
          BESVC[Service: backend (ClusterIP)]:::svc

          FEPOD[(Deployment: frontend Pods<br/>Nginx static React)]:::pod
          BEPOD[(Deployment: backend Pods<br/>Flask+Gunicorn<br/>/metrics exposed)]:::pod

          K8SSEC[(K8s Secret: backend-db)]:::sec
        end

        %% Service-to-pod bindings
        FESVC --> FEPOD
        BESVC --> BEPOD

        %% IRSA relationships (conceptual)
        EKS --> OIDC
        ALBC -.assumes via IRSA.-> OIDC
        ESO  -.assumes via IRSA.-> OIDC

      end %% EKS

      %% Database in private subnets
      RDS[(Amazon RDS PostgreSQL<br/>5432/TLS)]:::db

    end %% PRIV

  end %% VPC

  %% ----- Foundational AWS Services outside VPC context -----
  SM[(AWS Secrets Manager<br/>DB creds)]:::sec
  ECR[(Amazon ECR<br/>Container Images)]:::reg
  IAMROLES[(IAM Roles for Service Accounts<br/>(IRSA Policies))]:::iam

end %% AWS

%% ---------- CI/CD Plane ----------
GH[GitHub Actions<br/>(CI/CD)]:::ext
OIDC_GH[(GitHub OIDC Deploy Role<br/>(IAM))]:::iam


%% =========================================================
%% Traffic / Control Flows
%% =========================================================

%% User traffic through ALB to services
U -->|HTTP| ALB
ALB -->|path "/"| FESVC
ALB -->|path "/api"| BESVC

%% Backend ↔ Database
BEPOD -->|TLS 5432| RDS

%% Secrets flow (AWS SM → ESO → K8s Secret → App)
SM -->|read (scoped)| ESO
ESO -->|sync secret| K8SSEC
BEPOD -->|env from| K8SSEC

%% Observability: scrape, visualize, alert
BEPOD -- scrape /metrics --> PROM
PROM --> AM
GRAF --> PROM

%% ALB controller manages ALB
ALBC -.reconciles.-> ALB

%% GitHub Actions OIDC and deploys
GH -->|OIDC federates| OIDC_GH
OIDC_GH -->|push images| ECR
OIDC_GH -->|kubectl/helm<br/>deploy charts| EKS
OIDC_GH -->|terraform apply<br/>(infra modules)| AWS

%% =========================================================
%% Styling / Legend
%% =========================================================
classDef ext fill:#f5faff,stroke:#3578e5,stroke-width:1px,color:#0b2a6b;
classDef lb  fill:#fff2e6,stroke:#ff8b00,stroke-width:1px,color:#7a3f00;
classDef pod fill:#f0fff4,stroke:#0f9d58,stroke-width:1px,color:#0b5d39;
classDef svc fill:#e8f5ff,stroke:#1b73e8,stroke-width:1px,color:#0b2a6b;
classDef db  fill:#fff0f6,stroke:#e91e63,stroke-width:1px,color:#6d0033;
classDef obs fill:#efe9ff,stroke:#7a5af5,stroke-width:1px,color:#3b2e7e;
classDef sec fill:#fffde7,stroke:#c0a000,stroke-width:1px,color:#6b5a00;
classDef reg fill:#eefcf6,stroke:#00a37a,stroke-width:1px,color:#0b5d49;
classDef iam fill:#f3f3f3,stroke:#6e6e6e,stroke-width:1px,color:#2d2d2d;
classDef ctrl fill:#f2fbff,stroke:#00a2ff,stroke-width:1px,color:#004d73;
```

## Component Details

### Frontend (React + Nginx)
- **Technology**: React 18 + Vite, served by Nginx
- **Replica Count**: 1 (dev), 2+ (prod with HPA)
- **Resources**: 50m CPU / 64Mi RAM (requests)
- **Health Checks**: `/healthz` endpoint

### Backend (Flask + Gunicorn)
- **Technology**: Python 3.12 Flask API with Gunicorn WSGI server
- **Replica Count**: 2 (dev), 3+ (prod with HPA)
- **Resources**: 150m CPU / 256Mi RAM (requests)
- **Metrics**: Prometheus `/metrics` endpoint
- **Health Checks**: 
  - Liveness: `/healthz`
  - Readiness: `/readiness` (includes DB check)

### Database (RDS PostgreSQL)
- **Engine**: PostgreSQL 15.4
- **Instance**: db.t4g.micro (dev), db.t4g.medium (prod)
- **Multi-AZ**: Disabled (dev), Enabled (prod)
- **Backup**: 7 days (dev), 14 days (prod)
- **Connection**: TLS required, private subnet only

### Load Balancer (ALB)
- **Type**: Application Load Balancer (internet-facing)
- **Routing**:
  - `/` → Frontend service
  - `/api` → Backend service
- **Health Checks**: Configured per service

### Observability Stack
- **Prometheus**: Metrics collection, retention 36h (dev), 72h (prod)
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notification
- **ServiceMonitor**: Auto-discovery of backend metrics

## Security

### IRSA (IAM Roles for Service Accounts)
- ALB Controller: Manages ALB/NLB resources
- External Secrets Operator: Reads from Secrets Manager

### Secrets Management
- Database credentials stored in AWS Secrets Manager
- Synced to Kubernetes via External Secrets Operator
- Mounted as environment variables in backend pods

### Network Security
- Private subnets for EKS nodes and RDS
- Security groups restrict database access to EKS nodes only
- TLS encryption for database connections

## Deployment Flow

1. **Infrastructure**: Terraform provisions EKS, RDS, ECR, IAM roles
2. **Container Build**: GitHub Actions builds and scans images
3. **Image Push**: Tagged images pushed to ECR
4. **Helm Deploy**: Applications deployed via Helm charts
5. **Ingress**: ALB provisioned and configured automatically

## Monitoring & Alerts

See [slos.md](./slos.md) and [error-budgets.md](./error-budgets.md) for detailed SLO configuration and error budget policies.

## Scaling

### Horizontal Pod Autoscaling (HPA)
- **Backend**: 2-10 replicas based on 70% CPU / 80% memory
- **Frontend**: 1-3 replicas (prod only)

### Vertical Scaling
- RDS can be upgraded to larger instance classes
- EKS node group can be scaled or instance types changed

## Cost Optimization

- Small instance types (t3.medium for nodes, t4g.micro/medium for RDS)
- Short Prometheus retention to minimize storage
- On-demand instances (can switch to Spot for non-prod)
- ALB shared across services via path-based routing

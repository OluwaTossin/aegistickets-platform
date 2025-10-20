#!/bin/bash
set -e

echo "🚀 AegisTickets-Lite Deployment Script"
echo "======================================="
echo ""

# Configuration
ENVIRONMENT=${1:-dev}
AWS_REGION="eu-west-1"

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
  echo "Error: Environment must be 'dev' or 'prod'"
  echo "Usage: ./deploy.sh [dev|prod]"
  exit 1
fi

echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo ""

# Step 1: Apply Terraform infrastructure
echo "📦 Step 1/5: Deploying infrastructure with Terraform..."
cd infra/envs/$ENVIRONMENT
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Get outputs
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
ECR_FRONTEND=$(terraform output -raw ecr_frontend_repository_url)
ECR_BACKEND=$(terraform output -raw ecr_backend_repository_url)

echo "✅ Infrastructure deployed"
echo "   Cluster: $CLUSTER_NAME"
echo ""

# Step 2: Configure kubectl
echo "🔧 Step 2/5: Configuring kubectl..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
echo "✅ kubectl configured"
echo ""

# Step 3: Apply Kubernetes manifests
echo "☸️  Step 3/5: Applying Kubernetes manifests..."
kubectl apply -f ../../../deploy/manifests/namespace-$ENVIRONMENT.yaml
kubectl apply -f ../../../deploy/manifests/external-secret-$ENVIRONMENT.yaml
kubectl apply -f ../../../deploy/manifests/monitoring/prometheus-rules.yaml
echo "✅ Kubernetes manifests applied"
echo ""

# Step 4: Build and push images
echo "🐳 Step 4/5: Building and pushing Docker images..."
cd ../../../

# Get Git SHA for tagging
GIT_SHA=$(git rev-parse --short HEAD)

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $(echo $ECR_BACKEND | cut -d'/' -f1)

# Build and push backend
echo "Building backend..."
docker build -t $ECR_BACKEND:sha-$GIT_SHA -t $ECR_BACKEND:latest app/backend
docker push $ECR_BACKEND:sha-$GIT_SHA
docker push $ECR_BACKEND:latest

# Build and push frontend
echo "Building frontend..."
docker build -t $ECR_FRONTEND:sha-$GIT_SHA -t $ECR_FRONTEND:latest app/frontend
docker push $ECR_FRONTEND:sha-$GIT_SHA
docker push $ECR_FRONTEND:latest

echo "✅ Images pushed"
echo "   Backend: $ECR_BACKEND:sha-$GIT_SHA"
echo "   Frontend: $ECR_FRONTEND:sha-$GIT_SHA"
echo ""

# Step 5: Deploy applications with Helm
echo "⎈  Step 5/5: Deploying applications with Helm..."

NAMESPACE="tickets-$ENVIRONMENT"

# Deploy backend
helm upgrade --install backend deploy/helm/backend \
  -n $NAMESPACE \
  -f deploy/helm/backend/values-$ENVIRONMENT.yaml \
  --set image.tag=sha-$GIT_SHA \
  --wait --timeout 5m

# Deploy frontend
helm upgrade --install frontend deploy/helm/frontend \
  -n $NAMESPACE \
  -f deploy/helm/frontend/values-$ENVIRONMENT.yaml \
  --set image.tag=sha-$GIT_SHA \
  --wait --timeout 5m

# Apply ingress
kubectl apply -f deploy/manifests/ingress-$ENVIRONMENT.yaml

echo "✅ Applications deployed"
echo ""

# Get ALB DNS
echo "⏳ Waiting for ALB to be provisioned (30s)..."
sleep 30

ALB_DNS=$(kubectl -n $NAMESPACE get ingress tickets-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo ""
echo "=========================================="
echo "✨ Deployment Complete!"
echo "=========================================="
echo ""
echo "Application URL: http://$ALB_DNS"
echo ""
echo "Grafana (port-forward): kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80"
echo "  URL: http://localhost:3000"
echo "  Username: admin"
echo "  Password: (check Terraform outputs)"
echo ""
echo "Backend pods:"
kubectl -n $NAMESPACE get pods -l app=backend
echo ""
echo "Frontend pods:"
kubectl -n $NAMESPACE get pods -l app=frontend
echo ""

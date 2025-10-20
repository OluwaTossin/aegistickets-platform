#!/bin/bash

echo "🧹 Cleaning up AegisTickets infrastructure..."
echo ""

ENVIRONMENT=${1:-dev}

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
  echo "Error: Environment must be 'dev' or 'prod'"
  echo "Usage: ./cleanup.sh [dev|prod]"
  exit 1
fi

echo "Environment: $ENVIRONMENT"
echo ""

read -p "Are you sure you want to destroy the $ENVIRONMENT environment? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Cleanup cancelled"
  exit 0
fi

CLUSTER_NAME="tickets-$ENVIRONMENT"
NAMESPACE="tickets-$ENVIRONMENT"

# Step 1: Delete Kubernetes resources
echo "Step 1/3: Deleting Kubernetes resources..."
kubectl delete namespace $NAMESPACE --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true
kubectl delete namespace external-secrets --ignore-not-found=true

echo "✅ Kubernetes resources deleted"
echo ""

# Step 2: Delete Helm releases (if any remain)
echo "Step 2/3: Cleaning up Helm releases..."
helm uninstall backend -n $NAMESPACE --ignore-not-found 2>/dev/null || true
helm uninstall frontend -n $NAMESPACE --ignore-not-found 2>/dev/null || true

echo "✅ Helm releases cleaned"
echo ""

# Step 3: Destroy Terraform infrastructure
echo "Step 3/3: Destroying Terraform infrastructure..."
cd infra/envs/$ENVIRONMENT
terraform destroy -auto-approve

echo ""
echo "✅ Cleanup complete!"
echo ""

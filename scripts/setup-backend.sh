#!/bin/bash
set -e

echo "🔧 AegisTickets Terraform Backend Setup"
echo "========================================"
echo ""

AWS_REGION="eu-west-1"
ENVIRONMENT=${1:-dev}

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
  echo "Error: Environment must be 'dev' or 'prod'"
  echo "Usage: ./setup-backend.sh [dev|prod]"
  exit 1
fi

S3_BUCKET="aegis-tickets-tfstate-$ENVIRONMENT"
DYNAMODB_TABLE="aegis-tickets-tfstate-lock-$ENVIRONMENT"

echo "Setting up Terraform backend for: $ENVIRONMENT"
echo "S3 Bucket: $S3_BUCKET"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo "Region: $AWS_REGION"
echo ""

# Create S3 bucket
echo "Creating S3 bucket..."
if aws s3 ls s3://$S3_BUCKET 2>&1 | grep -q 'NoSuchBucket'; then
  aws s3api create-bucket \
    --bucket $S3_BUCKET \
    --region $AWS_REGION \
    --create-bucket-configuration LocationConstraint=$AWS_REGION

  # Enable versioning
  aws s3api put-bucket-versioning \
    --bucket $S3_BUCKET \
    --versioning-configuration Status=Enabled

  # Enable encryption
  aws s3api put-bucket-encryption \
    --bucket $S3_BUCKET \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'

  # Block public access
  aws s3api put-public-access-block \
    --bucket $S3_BUCKET \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  echo "✅ S3 bucket created: $S3_BUCKET"
else
  echo "✅ S3 bucket already exists: $S3_BUCKET"
fi

echo ""

# Create DynamoDB table
echo "Creating DynamoDB table..."
if ! aws dynamodb describe-table --table-name $DYNAMODB_TABLE --region $AWS_REGION >/dev/null 2>&1; then
  aws dynamodb create-table \
    --table-name $DYNAMODB_TABLE \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $AWS_REGION \
    --tags Key=Environment,Value=$ENVIRONMENT Key=ManagedBy,Value=Terraform

  echo "✅ DynamoDB table created: $DYNAMODB_TABLE"
else
  echo "✅ DynamoDB table already exists: $DYNAMODB_TABLE"
fi

echo ""
echo "=========================================="
echo "✨ Backend setup complete!"
echo "=========================================="
echo ""
echo "Update your backend.tf with:"
echo ""
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"$S3_BUCKET\""
echo "    key            = \"terraform.tfstate\""
echo "    region         = \"$AWS_REGION\""
echo "    dynamodb_table = \"$DYNAMODB_TABLE\""
echo "    encrypt        = true"
echo "  }"
echo "}"
echo ""

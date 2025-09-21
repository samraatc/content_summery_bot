#!/bin/bash

# AWS Deployment Script for Content Summary Bot
# This script deploys your Flask application to AWS ECS with Fargate

set -e

# Configuration
REGION="us-east-1"  # Change this to your preferred region
CLUSTER_NAME="content-summary-bot-cluster"
SERVICE_NAME="content-summary-bot-service"
REPOSITORY_NAME="content-summary-bot"
TASK_FAMILY="content-summary-bot-task"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting AWS ECS Deployment for Content Summary Bot${NC}"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPOSITORY_NAME}"

echo -e "${YELLOW}📋 Using AWS Account: ${ACCOUNT_ID}${NC}"
echo -e "${YELLOW}📋 Using Region: ${REGION}${NC}"

# Step 1: Create ECR Repository if it doesn't exist
echo -e "${GREEN}📦 Step 1: Creating ECR Repository...${NC}"
aws ecr describe-repositories --region ${REGION} --repository-names ${REPOSITORY_NAME} &> /dev/null || {
    echo "Creating ECR repository..."
    aws ecr create-repository --region ${REGION} --repository-name ${REPOSITORY_NAME}
}

# Step 2: Login to ECR
echo -e "${GREEN}🔐 Step 2: Logging into ECR...${NC}"
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Step 3: Build Docker image
echo -e "${GREEN}🔨 Step 3: Building Docker image...${NC}"
docker build -t ${REPOSITORY_NAME} .
docker tag ${REPOSITORY_NAME}:latest ${ECR_URI}:latest

# Step 4: Push image to ECR
echo -e "${GREEN}⬆️  Step 4: Pushing image to ECR...${NC}"
docker push ${ECR_URI}:latest

# Step 5: Create ECS Cluster if it doesn't exist
echo -e "${GREEN}🏗️  Step 5: Creating ECS Cluster...${NC}"
aws ecs describe-clusters --region ${REGION} --clusters ${CLUSTER_NAME} &> /dev/null || {
    echo "Creating ECS cluster..."
    aws ecs create-cluster --region ${REGION} --cluster-name ${CLUSTER_NAME} --capacity-providers FARGATE --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
}

# Step 6: Create CloudWatch Log Group
echo -e "${GREEN}📊 Step 6: Creating CloudWatch Log Group...${NC}"
aws logs describe-log-groups --region ${REGION} --log-group-name-prefix "/ecs/content-summary-bot" &> /dev/null || {
    echo "Creating CloudWatch log group..."
    aws logs create-log-group --region ${REGION} --log-group-name "/ecs/content-summary-bot"
}

# Step 7: Update task definition with actual values
echo -e "${GREEN}📝 Step 7: Preparing task definition...${NC}"
sed "s/{ACCOUNT_ID}/${ACCOUNT_ID}/g; s/{REGION}/${REGION}/g; s|{ECR_REPOSITORY_URI}|${ECR_URI}|g" task-definition.json > task-definition-updated.json

# Step 8: Register task definition
echo -e "${GREEN}📋 Step 8: Registering task definition...${NC}"
aws ecs register-task-definition --region ${REGION} --cli-input-json file://task-definition-updated.json

# Step 9: Create or update ECS service
echo -e "${GREEN}🚀 Step 9: Creating/Updating ECS Service...${NC}"
aws ecs describe-services --region ${REGION} --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} &> /dev/null && {
    echo "Updating existing service..."
    aws ecs update-service --region ${REGION} --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --task-definition ${TASK_FAMILY}
} || {
    echo "Creating new service..."
    aws ecs create-service \
        --region ${REGION} \
        --cluster ${CLUSTER_NAME} \
        --service-name ${SERVICE_NAME} \
        --task-definition ${TASK_FAMILY} \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[subnet-12345,subnet-67890],securityGroups=[sg-12345],assignPublicIp=ENABLED}" \
        --load-balancers targetGroupArn=arn:aws:elasticloadbalancing:${REGION}:${ACCOUNT_ID}:targetgroup/content-summary-bot-tg/1234567890123456,containerName=content-summary-bot,containerPort=5000
}

# Cleanup
rm -f task-definition-updated.json

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${YELLOW}🔗 Your application should be available at your Load Balancer DNS name.${NC}"
echo -e "${YELLOW}📊 Monitor your application in the AWS ECS console.${NC}"
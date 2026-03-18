#!/bin/bash
set -e

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
DOCKER_USERNAME="${DOCKER_USERNAME:-kwameduodu}"
DOCKER_PASSWORD="${DOCKER_PASSWORD:-Edulenseswen}"
IMAGE_NAME="edulense-program-grader"
TAG="latest"

# Check if using AWS ECR or Docker Hub
# If AWS credentials are provided, use ECR; otherwise use Docker Hub
if [ -n "$AWS_REPO_URL" ] && [ -n "$AWS_REG_ID" ]; then
  echo "Using AWS ECR registry..."
  
  # Docker login to AWS ECR
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_REG_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
  
  # Build and tag Docker image for ECR
  docker build -t "$IMAGE_NAME" .
  docker tag "$IMAGE_NAME:latest" "$AWS_REPO_URL:latest"
  
  # Push to ECR
  docker push "$AWS_REPO_URL:latest"
  echo "Docker image pushed successfully to $AWS_REPO_URL:latest"
else
  echo "Using Docker Hub registry..."
  
  # Docker login to Docker Hub
  echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
  
  # Build and tag Docker image for Docker Hub
  docker build -t "$IMAGE_NAME" .
  docker tag "$IMAGE_NAME:latest" "$DOCKER_USERNAME/$IMAGE_NAME:$TAG"
  
  # Push to Docker Hub
  docker push "$DOCKER_USERNAME/$IMAGE_NAME:$TAG"
  echo "Docker image pushed successfully to $DOCKER_USERNAME/$IMAGE_NAME:$TAG"
fi

echo "Build and push complete!"

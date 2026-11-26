#!/bin/bash
set -euo pipefail

echo "Starting Techcake application..."

REGION="ap-south-1"

# Read production settings securely from Parameter Store
PARAMS=$(aws ssm get-parameters-by-path \
  --path /techcake/app/ \
  --recursive \
  --with-decryption \
  --region "$REGION" \
  --output json)

get_param() {
  jq -er --arg name "/techcake/app/$1" \
    '.Parameters[] | select(.Name == $name) | .Value' <<< "$PARAMS"
}

IMAGE_URI=$(cat /opt/techcake-deploy/image_uri.txt)
VERSION="${IMAGE_URI##*:}"

DB_HOST=$(get_param DB_HOST)
DB_NAME=$(get_param DB_NAME)
DB_USER=$(get_param DB_USER)
DB_PASSWORD=$(get_param DB_PASSWORD)
DB_PORT=$(get_param DB_PORT)
DB_ENGINE=$(get_param DB_ENGINE)
DJANGO_SECRET_KEY=$(get_param DJANGO_SECRET_KEY)
DJANGO_ALLOWED_HOSTS=$(get_param DJANGO_ALLOWED_HOSTS)
CSRF_TRUSTED_ORIGINS=$(get_param CSRF_TRUSTED_ORIGINS)
REDIS_URL=$(get_param REDIS_URL)
AWS_STORAGE_BUCKET_NAME=$(get_param AWS_STORAGE_BUCKET_NAME)
AWS_S3_REGION_NAME=$(get_param AWS_S3_REGION_NAME)

# Add this instance's private IP to allowed hosts
TOKEN=$(curl -fsS -X PUT \
  "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_PRIVATE_IP=$(curl -fsS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

DJANGO_ALLOWED_HOSTS="${DJANGO_ALLOWED_HOSTS},${INSTANCE_PRIVATE_IP}"

# Start the new application container
docker rm -f techcake-app 2>/dev/null || true

docker run -d \
  --name techcake-app \
  --restart unless-stopped \
  -p 8000:8000 \
  -e DJANGO_SECRET_KEY="$DJANGO_SECRET_KEY" \
  -e DJANGO_DEBUG=false \
  -e DJANGO_ALLOWED_HOSTS="$DJANGO_ALLOWED_HOSTS" \
  -e CSRF_TRUSTED_ORIGINS="$CSRF_TRUSTED_ORIGINS" \
  -e DJANGO_CSRF_TRUSTED_ORIGINS="$CSRF_TRUSTED_ORIGINS" \
  -e DB_ENGINE="$DB_ENGINE" \
  -e DB_NAME="$DB_NAME" \
  -e DB_USER="$DB_USER" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e DB_HOST="$DB_HOST" \
  -e DB_PORT="$DB_PORT" \
  -e REDIS_URL="$REDIS_URL" \
  -e AWS_STORAGE_BUCKET_NAME="$AWS_STORAGE_BUCKET_NAME" \
  -e AWS_S3_REGION_NAME="$AWS_S3_REGION_NAME" \
  -e APP_VERSION="$VERSION" \
  "$IMAGE_URI"

echo "Application container started."

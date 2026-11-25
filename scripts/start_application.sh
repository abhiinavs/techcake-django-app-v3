#!/bin/bash
set -euo pipefail

echo "Starting Techcake application..."

cd /opt/techcake-deploy

IMAGE_URI=$(cat image_uri.txt)

docker rm -f techcake-app || true

docker run -d \
  --name techcake-app \
  --restart unless-stopped \
  -p 8000:8000 \
  -e APP_VERSION="${IMAGE_URI##*:}" \
  "$IMAGE_URI"

echo "Application container started."

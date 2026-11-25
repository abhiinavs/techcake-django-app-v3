#!/bin/bash
set -euo pipefail

echo "Starting CodeDeploy AfterInstall..."

cd /opt/techcake-deploy

if [ ! -s image_uri.txt ]; then
  echo "ERROR: image_uri.txt is missing or empty."
  exit 1
fi

IMAGE_URI=$(cat image_uri.txt)
echo "Docker image to deploy: $IMAGE_URI"

docker pull "$IMAGE_URI"

echo "AfterInstall completed."

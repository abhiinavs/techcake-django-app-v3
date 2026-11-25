#!/bin/bash
set -euo pipefail

echo "Validating Techcake application..."

HEALTH_FILE="/tmp/techcake-health.json"

for attempt in {1..30}; do
  if curl -fsS http://localhost:8000/health -o "$HEALTH_FILE"; then
    break
  fi

  echo "Waiting for application... attempt $attempt"
  sleep 5
done

if [ ! -s "$HEALTH_FILE" ]; then
  echo "ERROR: Application health check failed."
  exit 1
fi

EXPECTED_VERSION=$(cat /opt/techcake-deploy/image_uri.txt)
EXPECTED_VERSION="${EXPECTED_VERSION##*:}"

if ! grep -Fq "$EXPECTED_VERSION" "$HEALTH_FILE"; then
  echo "ERROR: Deployed version does not match expected version."
  cat "$HEALTH_FILE"
  exit 1
fi

echo "Validation successful:"
cat "$HEALTH_FILE"

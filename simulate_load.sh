#!/bin/bash


set -euo pipefail

# Input arguments
GROUP_NAME=$1
ZONE=$2
MIN_REPLICAS=$3
DURATION=$4

echo ">>> Checking prerequisites..."

# Install stress-ng if not available
if ! command -v stress-ng >/dev/null; then
  echo ">>> Installing stress-ng for CPU load generation..."
  sudo apt-get update && sudo apt-get install -y stress-ng
fi

# Detect total CPU cores
CPU_CORES=$(nproc)
echo ">>> CPU Cores available: $CPU_CORES"
echo ">>> Starting stress test for $DURATION seconds..."

# Launch CPU stress test
stress-ng --cpu "$CPU_CORES" --timeout "${DURATION}"

echo ">>> Load test completed. Monitoring auto-scaling..."

# Wait a bit for auto-scaler to respond
WAIT_TIME=20
echo ">>> Waiting ${WAIT_TIME}s for scaling to react..."
sleep "$WAIT_TIME"

# Track scale-down over time
ATTEMPTS=0
MAX_RETRIES=10

while [ "$ATTEMPTS" -lt "$MAX_RETRIES" ]; do
  ACTIVE_INSTANCES=$(gcloud compute instance-groups managed list-instances "$GROUP_NAME" --zone "$ZONE" --format="value(instance)" | wc -l)
  echo ">>> Current instance count: $ACTIVE_INSTANCES"

  if [ "$ACTIVE_INSTANCES" -le "$MIN_REPLICAS" ]; then
    echo ">>> ✅ Scaled down successfully to baseline: $MIN_REPLICAS instance(s)."
    exit 0
  fi

  sleep 30
  ((ATTEMPTS++))
done

echo ">>> ❌ Timeout: Instance group did not scale down within expected timeframe."
exit 1

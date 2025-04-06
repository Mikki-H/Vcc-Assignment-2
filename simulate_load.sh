#!/bin/bash
# Usage: ./simulate_load.sh <GROUP_ID> <ZONE> <MIN_EXPECTED_INSTANCES> <DURATION_SEC>

set -euo pipefail

GROUP_ID=$1
ZONE=$2
EXPECTED_MIN=$3
DURATION=$4

echo ">>> Checking prerequisites..."

if ! command -v stress-ng >/dev/null; then
  echo ">>> Installing stress-ng for CPU load generation..."
  sudo apt-get update && sudo apt-get install -y stress-ng
fi

CORES=$(nproc)
echo ">>> CPU Cores available: $CORES"
echo ">>> Starting stress test for ${DURATION} seconds..."

# Apply double CPU load to trigger autoscaling
stress-ng --cpu "$((CORES * 2))" --timeout "${DURATION}"s --metrics-brief

echo ">>> Load test completed. Monitoring auto-scaling..."
echo ">>> Waiting 20s for scaling to react..."
sleep 20

echo ">>> Checking current VM count in instance group..."
CURRENT_REPLICAS=$(gcloud compute instance-groups managed list-instances "$GROUP_ID" --zone "$ZONE" --format="value(instance)" | wc -l)
echo ">>> Currently running instances: $CURRENT_REPLICAS"

if [[ $CURRENT_REPLICAS -le $EXPECTED_MIN ]]; then
  echo "✅ Scaling has returned to baseline ($CURRENT_REPLICAS instance(s))"
else
  echo "⚠️  More than expected baseline VMs running: $CURRENT_REPLICAS instance(s)"
fi

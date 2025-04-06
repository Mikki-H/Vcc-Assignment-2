#!/bin/bash
# Custom CPU stress tester and MIG monitor

set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <MIG_NAME> <ZONE> <MIN_INSTANCES> <DURATION_IN_SEC>"
  exit 1
fi

GROUP_ID=$1
ZONE=$2
MIN_COUNT=$3
DURATION=$4

echo "[START] Verifying prerequisites..."

if ! command -v stress-ng >/dev/null; then
  echo "[INFO] Installing stress-ng..."
  sudo apt update && sudo apt install -y stress-ng
fi

if ! command -v gcloud >/dev/null; then
  echo "[ERROR] gcloud CLI is missing. Exiting."
  exit 1
fi

CPU_CORES=$(nproc)
echo "[INFO] Detected $CPU_CORES cores. Running CPU load for $DURATION seconds..."
stress-ng --cpu "$CPU_CORES" --timeout "${DURATION}s"

echo "[INFO] Load finished. Waiting for scaling activity..."
sleep 60

MAX_WAIT=600
INTERVAL=30
TIME_PASSED=0

while [ "$TIME_PASSED" -lt "$MAX_WAIT" ]; do
  CURRENT_REPLICAS=$(gcloud compute instance-groups managed list-instances "$GROUP_ID" \
    --zone "$ZONE" --format="value(instance)" | wc -l)

  echo "[STATUS] Current replica count: $CURRENT_REPLICAS"

  if [[ "$CURRENT_REPLICAS" -le "$MIN_COUNT" ]]; then
    echo "[SUCCESS] Group has returned to minimum ($MIN_COUNT) instances."
    exit 0
  fi

  sleep "$INTERVAL"
  TIME_PASSED=$((TIME_PASSED + INTERVAL))
done

echo "[TIMEOUT] Auto-scaler did not scale down in expected time."
exit 1

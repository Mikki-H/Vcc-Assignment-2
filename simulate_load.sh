
set -euo pipefail

GROUP_NAME=$1
ZONE=$2
BASE_COUNT=$3
DURATION=$4

echo ">>> Checking prerequisites..."

# Ensure dpkg issues are cleared
sudo dpkg --configure -a


if ! command -v stress-ng &> /dev/null; then
  echo ">>> Installing stress-ng for CPU load generation..."
  sudo apt update
  sudo apt install -y stress-ng
fi

CORES=$(nproc)
echo ">>> CPU Cores available: $CORES"
echo ">>> Starting stress test for ${DURATION} seconds..."

# Run CPU load
stress-ng --cpu "$CORES" --timeout "${DURATION}"s

echo ">>> Load test completed. Monitoring auto-scaling..."
echo ">>> Waiting 20s for scaling to react..."
sleep 20

MAX_CHECKS=10
TRIES=0

while [ $TRIES -lt $MAX_CHECKS ]; do
  echo ">>> Checking current VM count in instance group..."
  CURRENT_COUNT=$(gcloud compute instance-groups managed list-instances "$GROUP_NAME" --zone "$ZONE" --format="value(instance)" | wc -l)

  echo ">>> Currently running instances: $CURRENT_COUNT"

  if [ "$CURRENT_COUNT" -le "$BASE_COUNT" ]; then
    echo "✅ Scaling has returned to baseline (${BASE_COUNT} instance(s))"
    exit 0
  fi

  sleep 30
  ((TRIES++))
done

echo "❌ Auto-scaling did not revert within the expected time."
exit 1

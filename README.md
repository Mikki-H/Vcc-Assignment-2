# GCP Auto-Scaling Test Script

This script is designed to test **auto-scaling behavior** of a **Google Cloud Platform (GCP) Managed Instance Group (MIG)** by generating high CPU load using `stress-ng`. It also verifies whether the scaling group returns to the expected baseline number of instances after the load is removed.

---

## ✅ Features

- Installs `stress-ng` if not present
- Generates CPU stress on the instance
- Monitors scaling reaction by checking the number of instances in the group
- Verifies whether the group has scaled beyond the expected minimum

---

## 🧾 Prerequisites

- GCP CLI (`gcloud`) installed and authenticated
- Proper IAM permissions to read and interact with the specified Managed Instance Group
- The VM must run a Debian-based Linux OS with access to `apt`
- The target instance must belong to a Managed Instance Group (MIG) with CPU-based auto-scaling enabled

---

## 📂 Script File

Save the following script as `autoscale-test.sh`:

```bash
#!/bin/bash
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
  echo " Scaling has returned to baseline ($CURRENT_REPLICAS instance(s))"
else
  echo "  More than expected baseline VMs running: $CURRENT_REPLICAS instance(s)"
fi

✅ 1. Make the script executable - chmod +x simulate_load.sh
✅ 2. Run the script - ./simulate_load.sh instance-group-1 asia-south1-c 1 180

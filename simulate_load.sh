
set -euo pipefail

GROUP_ID=$1
ZONE=$2
EXPECTED_MIN=$3
DURATION=$4

echo "[+] Validating system environment..."


if sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; then
  echo "[!] dpkg is locked. Attempting to fix..."
  sudo dpkg --configure -a
fi

if ! command -v stress-ng >/dev/null; then
  echo "[+] Installing stress-ng tool..."
  sudo apt-get update && sudo apt-get install -y stress-ng
fi


CORES=$(nproc)
echo "[+] Detected $CORES CPU core(s)"
echo "[+] Simulating load for ${DURATION} seconds..."


stress-ng --cpu "$CORES" --timeout "${DURATION}"s

echo "[+] Load test completed. Waiting 70 seconds for scaling to respond..."
sleep 70


ATTEMPTS=0
MAX_ATTEMPTS=10

while [ "$ATTEMPTS" -lt "$MAX_ATTEMPTS" ]; do
  CURRENT_REPLICAS=$(gcloud compute instance-groups managed list-instances "$GROUP_ID" --zone "$ZONE" --format="value(instance)" | wc -l)
  echo "[+] Current replicas: $CURRENT_REPLICAS"

  if [[ "$CURRENT_REPLICAS" -le "$EXPECTED_MIN" ]]; then
    echo "[✓] Instance group returned to baseline ($EXPECTED_MIN replica(s))"
    exit 0
  fi

  sleep 30
  ((ATTEMPTS++))
done

echo "[✗] Timeout: Scaling did not revert within expected duration."
exit 1

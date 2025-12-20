
#!/bin/bash
set -euo pipefail

IMAGE="$1"
[ -z "$IMAGE" ] && { echo "Usage: $0 <image:tag>"; exit 1; }

TMPDIR=$(mktemp -d)
CTR="ctr-$(date +%s%N)"

echo
echo "========== IMAGE: $IMAGE =========="

echo
echo "----------- Image size -----------"
docker images 2> /dev/null | grep "$IMAGE" || echo "Image not found locally"

echo
echo "----------- Default user -----------"
docker inspect "$IMAGE" | jq -r '.[0].Config.User // "root (default)"'

echo
echo "----------- Trivy scan -----------"
trivy image -q "$IMAGE" \
  | grep -A 6 "Report Summary" || echo "No summary found"

docker create --name "$CTR" "$IMAGE" >/dev/null
docker export "$CTR" -o filesystem.tar
docker rm "$CTR" >/dev/null

sudo tar -xf filesystem.tar -C "$TMPDIR"
rm filesystem.tar

echo
echo "----------- Filesystem metrics -----------"
echo "Total files:"
sudo find "$TMPDIR" -type f | wc -l

echo
echo "Executable files:"
sudo find "$TMPDIR" -type f -executable | wc -l

echo
echo "ELF binaries (real executables):"
sudo find "$TMPDIR" -type f -executable -exec file {} \; \
  | grep -c ELF

sudo rm -rf "$TMPDI






note: You must install jq and trivy before you run the script.

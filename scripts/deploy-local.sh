#!/usr/bin/env bash
# LOCAL deploy via icp-cli. The managed local network ships a real ICP ledger
# at the standard ryjl3-tyaaa-aaaaa-aaaba-cai, so local runs the REAL ICRC-2
# flow with production parity (same ledger id as mainnet).
#
# Mainnet deploys are a separate, manually-approved flow: docs/DEPLOY_RUNBOOK.md.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! icp network status >/dev/null 2>&1; then
  echo "Starting local network..."
  icp network start -d
fi

# Two-pass: square_core's init args need the escrow's canister id.
icp deploy square_escrow -e local
ESCROW_ID=$(python3 -c "import json; print(json.load(open('.icp/cache/mappings/local.ids.json'))['square_escrow'])")

cat > deploy/local/square_core.args <<EOF
(record { escrowId = principal "$ESCROW_ID" })
EOF

icp deploy -e local

echo
echo "Local deploy complete:"
python3 -c "import json; [print(f'  {k}: {v}') for k, v in json.load(open('.icp/cache/mappings/local.ids.json')).items()]"
echo
echo "Trust page: http://$(python3 -c "import json; print(json.load(open('.icp/cache/mappings/local.ids.json'))['frontend_assets'])").localhost:8000/"
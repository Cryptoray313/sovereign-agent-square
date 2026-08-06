#!/usr/bin/env bash
# Local deploy: dfx with the mops-pinned moc (dfx 0.32.0 bundles an older moc).
set -euo pipefail
cd "$(dirname "$0")/.."

DFX_MOC_PATH="$(mops toolchain bin moc)"
export DFX_MOC_PATH

if ! dfx ping >/dev/null 2>&1; then
  echo "Starting local replica..."
  dfx start --background --clean
fi

dfx deploy
echo
dfx canister status --all 2>/dev/null | grep -E 'Canister|Status' || true
echo "Local deploy complete."

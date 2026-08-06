#!/usr/bin/env bash
# LOCAL deploy only: dfx with the mops-pinned moc, plus init-arg wiring
# (test_ledger -> square_escrow -> square_core). The test_ledger is TEST ONLY
# and must never reach mainnet; Phase 2 gets its own mainnet deploy flow with
# the real ICP ledger id.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${DFX_NETWORK:-local}" != "local" ]; then
  echo "REFUSING: this script deploys the TEST ledger and is local-only." >&2
  exit 1
fi

DFX_MOC_PATH="$(mops toolchain bin moc)"
export DFX_MOC_PATH

if ! dfx ping >/dev/null 2>&1; then
  echo "Starting local replica..."
  dfx start --background --clean
fi

# Fund the current dfx identity on the dummy ledger for manual poking.
ME=$(dfx identity get-principal)

dfx deploy constitution
dfx deploy test_ledger --argument "(record {
  initialBalances = vec {
    record { record { owner = principal \"$ME\"; subaccount = null }; 1_000_000_000 : nat };
  };
  fee = 10_000 : nat;
})"

LEDGER_ID=$(dfx canister id test_ledger)
# minDeadlineNs 60s; reviewWindowNs 72h (draft — TODO OPEN QUESTION in types.mo).
dfx deploy square_escrow --argument "(record {
  ledgerId = principal \"$LEDGER_ID\";
  opCapE8s = 100_000_000 : nat;
  minDeadlineNs = 60_000_000_000 : nat;
  reviewWindowNs = 259_200_000_000_000 : nat;
})"

ESCROW_ID=$(dfx canister id square_escrow)
dfx deploy square_core --argument "(record { escrowId = principal \"$ESCROW_ID\" })"

dfx deploy frontend_assets

echo
echo "Local deploy complete:"
for c in constitution test_ledger square_escrow square_core frontend_assets; do
  echo "  $c: $(dfx canister id "$c")"
done
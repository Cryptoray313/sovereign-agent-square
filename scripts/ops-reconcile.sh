#!/usr/bin/env bash
# Ops-test honesty reconciliation (standing guard, alongside forbidden-grep.sh
# and core-write-path-check.sh).
#
# INVARIANT: every principal that appears in an on-chain escrow receipt (client
# or agent) must be DELIBERATELY classified in the shared registry
# canisters/frontend_assets/src/lib/ops-registry.json — as `opsTest` (an
# internal operator account) or `external` (a verified external participant).
# An on-chain principal in neither list is "unaccounted": the UI renders it
# "unlabeled" and THIS CHECK FAILS THE BUILD — so the site can never silently
# present an unknown as ops-test, and drift is caught before publication.
#
# Data source order:
#   1) LIVE  — query mainnet via icp-cli (works in CI) or dfx; authoritative.
#   2) SNAPSHOT — the committed scripts/ops-onchain-snapshot.json, used only
#      when the chain/tooling is unreachable. Refresh it with `--refresh`.
#   3) neither — SKIP with a loud notice (never fail the build on pure infra;
#      this is a maintainer honesty guard, not an adversarial gate).
#
# Usage: scripts/ops-reconcile.sh [--refresh] [--offline]
set -euo pipefail
cd "$(dirname "$0")/.."

REGISTRY="canisters/frontend_assets/src/lib/ops-registry.json"
SNAPSHOT="scripts/ops-onchain-snapshot.json"
MAPPING=".icp/data/mappings/mainnet.ids.json"
MAX_SCAN=2000
REFRESH=0; OFFLINE=0
for a in "$@"; do
  case "$a" in
    --refresh) REFRESH=1 ;;
    --offline) OFFLINE=1 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

# --- registry (single source of truth, shared with the UI) ---
if [ ! -f "$REGISTRY" ]; then
  echo "ops-reconcile: registry $REGISTRY missing" >&2; exit 1
fi
# Emits every classified principal, one per line.
registry_principals() {
  python3 -c "import json,sys
d=json.load(open('$REGISTRY'))
for k in list(d.get('opsTest',{})) + list(d.get('external',{})): print(k)"
}

escrow_id() {
  python3 -c "import json;print(json.load(open('$MAPPING'))['square_escrow'])" 2>/dev/null
}

# --- gather on-chain principals ---
# Prints distinct client+agent principals (one per line) to stdout, and the
# receiptsCount to fd 3 (captured by the caller). Empty stdout = no data.
onchain_principals() {
  local eid; eid="$(escrow_id)"; [ -n "$eid" ] || return 1
  local trust count out cli agt
  # Pick a query transport.
  local q=""
  if command -v icp >/dev/null 2>&1 && icp canister call square_escrow getTrustInfo '()' -e mainnet --query >/dev/null 2>&1; then
    q="icp"
  elif command -v dfx >/dev/null 2>&1 && dfx canister call "$eid" getTrustInfo '()' --network ic --query >/dev/null 2>&1; then
    q="dfx"
  else
    return 1
  fi
  _call() { # $1 = candid args
    if [ "$q" = "icp" ]; then icp canister call square_escrow "$2" "$1" -e mainnet --query 2>/dev/null
    else dfx canister call "$eid" "$2" "$1" --network ic --query 2>/dev/null; fi
  }
  trust="$(_call '()' getTrustInfo)"
  count="$(echo "$trust" | grep -oE 'receiptsCount = [0-9_]+' | grep -oE '[0-9_]+' | tr -d '_')"
  [ -n "$count" ] || return 1
  echo "$count" >&3
  # Receipt ids are JOB ids, which are NOT contiguous with receiptsCount (many
  # jobs never settle: open/cancelled/refunded leave gaps, and live job ids run
  # far ahead of the receipt total). So we walk ids upward until we've LOCATED
  # all `count` receipts (early-exit), not merely to count+N. If we hit MAX_SCAN
  # before finding them all, that is a loud failure — never a silent skip.
  local scanned=0 id=0
  while [ "$scanned" -lt "$count" ] && [ "$id" -lt "$MAX_SCAN" ]; do
    out="$(_call "($id)" getReceipt)"
    id=$((id+1))
    echo "$out" | grep -q 'record' || continue
    scanned=$((scanned+1))
    echo "$out" | grep -oE 'client = principal "[a-z0-9-]+"' | grep -oE '"[a-z0-9-]+"' | tr -d '"'
    echo "$out" | grep -oE ' agent = principal "[a-z0-9-]+"' | grep -oE '"[a-z0-9-]+"' | tr -d '"'
  done
  if [ "$scanned" -lt "$count" ]; then
    echo "ops-reconcile: located only $scanned of $count receipts within id<$MAX_SCAN — raise MAX_SCAN." >&2
    return 1
  fi
}

COUNT=""; SOURCE=""; ONCHAIN=""
if [ "$OFFLINE" -eq 0 ]; then
  if ONCHAIN="$( { onchain_principals; } 3>/tmp/ops_count.$$ 2>/dev/null )" && [ -s /tmp/ops_count.$$ ]; then
    COUNT="$(cat /tmp/ops_count.$$)"; SOURCE="mainnet (live)"
  fi
  rm -f /tmp/ops_count.$$
fi
if [ -z "$SOURCE" ]; then
  if [ -f "$SNAPSHOT" ]; then
    ONCHAIN="$(python3 -c "import json;print('\n'.join(json.load(open('$SNAPSHOT'))['principals']))")"
    COUNT="$(python3 -c "import json;print(json.load(open('$SNAPSHOT')).get('receiptsCount','?'))")"
    SOURCE="committed snapshot ($SNAPSHOT)"
    echo "ops-reconcile: chain unreachable — reconciling committed snapshot instead." >&2
  else
    echo "ops-reconcile: no chain access and no snapshot — SKIPPING (no data to verify)." >&2
    echo "ops-reconcile: skipped"
    exit 0
  fi
fi

# Distinct, sorted.
ONCHAIN_SORTED="$(printf '%s\n' "$ONCHAIN" | grep -vE '^$' | sort -u)"
REG="$(registry_principals | sort -u)"

# Unaccounted = on-chain principals not in the registry.
UNACCOUNTED="$(comm -23 <(printf '%s\n' "$ONCHAIN_SORTED") <(printf '%s\n' "$REG"))"

N_ONCHAIN="$(printf '%s\n' "$ONCHAIN_SORTED" | grep -cvE '^$' || true)"
N_OPS="$(python3 -c "import json;print(len(json.load(open('$REGISTRY'))['opsTest']))")"
N_EXT="$(python3 -c "import json;print(len(json.load(open('$REGISTRY'))['external']))")"

# --refresh: rewrite the committed snapshot from the live scan.
if [ "$REFRESH" -eq 1 ] && [ "$SOURCE" = "mainnet (live)" ]; then
  python3 -c "import json
snap={'source':'mainnet','receiptsCount':int('$COUNT'),
'principals':sorted('''$ONCHAIN_SORTED'''.split())}
json.dump(snap, open('$SNAPSHOT','w'), indent=2); open('$SNAPSHOT','a').write('\n')"
  echo "ops-reconcile: snapshot refreshed → $SNAPSHOT"
fi

echo "ops-reconcile: source=$SOURCE  receiptsCount=$COUNT  on-chain principals=$N_ONCHAIN  registry=$N_OPS ops-test + $N_EXT external"

if [ -n "$UNACCOUNTED" ]; then
  echo "" >&2
  echo "FAILED: on-chain receipt principal(s) not classified in $REGISTRY:" >&2
  printf '  ❌ %s\n' $UNACCOUNTED >&2
  echo "" >&2
  echo "Each is EITHER a real external participant (add to \"external\") OR an" >&2
  echo "ops identity the registry is missing (add to \"opsTest\"). Classify it" >&2
  echo "deliberately, then re-run. The UI shows it \"unlabeled\" until you do." >&2
  exit 1
fi

echo "ops-reconcile: clean — every on-chain receipt principal is classified (ops-test or external)."

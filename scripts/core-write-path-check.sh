#!/usr/bin/env bash
# Enforces the spine/lobby separation (handoff §4):
#   1. square_core sees escrow ONLY through lib/EscrowReader.mo, and every
#      method in that interface is a query (zero write-path into escrow).
#   2. square_escrow never imports or references square_core.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

# 1a) Every actor method in EscrowReader.mo must be a query.
READER=canisters/square_core/lib/EscrowReader.mo
nonquery=$(grep -E ':\s*shared\s' "$READER" | grep -v 'shared query' || true)
if [ -n "$nonquery" ]; then
  echo "FORBIDDEN: non-query method in $READER:" >&2
  echo "$nonquery" >&2
  fail=1
fi

# 1b) square_core must not declare any other escrow actor surface.
other=$(grep -rn 'actor' canisters/square_core --include='*.mo' \
  | grep -vE 'persistent actor|EscrowReader|lib/EscrowReader\.mo' || true)
if [ -n "$other" ]; then
  echo "FORBIDDEN: square_core references an actor outside EscrowReader:" >&2
  echo "$other" >&2
  fail=1
fi

# 2) square_escrow must never reference square_core.
if grep -rn 'square_core\|SquareCore' canisters/square_escrow --include='*.mo'; then
  echo "FORBIDDEN: square_escrow references square_core (spine must not call lobby)." >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "core-write-path-check: clean"
fi
exit "$fail"

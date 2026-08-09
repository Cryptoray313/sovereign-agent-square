#!/usr/bin/env bash
# The forbidden-reference grep (handoff §2, L8).
#
# Code surfaces must contain ZERO wiring to the author's prior projects: no
# code, canister IDs, principals, or keys copied from any earlier system — and
# no founder escape hatches. SAS is greenfield.
#
# The specific prior-project name tokens are NOT kept in this public tree. They
# are supplied at check time from either:
#   * the FORBIDDEN_TOKENS env var (CI: a repo secret), or
#   * a local, gitignored .forbidden file (one ERE alternative per line).
# When neither is present (e.g. a fresh public clone), the name check is
# skipped with a notice; the security-critical checks below always run.
#
# docs/, README.md, AGENTS.md and this script are excluded from the name check
# (governance text may legitimately discuss provenance); code may not.
set -euo pipefail
cd "$(dirname "$0")/.."

CODE_PATHS=(canisters tests icp.yaml mops.toml deploy scripts/deploy-local.sh .github)
# Vendored/generated files (gitignored) are not code surfaces.
EXCLUDES=(-I --exclude-dir=node_modules --exclude-dir=dist)

fail=0

# Assemble the prior-project name pattern from env or the private .forbidden.
name_pattern=""
if [ -n "${FORBIDDEN_TOKENS:-}" ]; then
  name_pattern="$FORBIDDEN_TOKENS"
elif [ -f .forbidden ]; then
  name_pattern="$(grep -vE '^[[:space:]]*(#|$)' .forbidden | paste -sd '|' -)"
fi

# 1) Forbidden prior-project references (word-bounded ERE).
if [ -n "$name_pattern" ]; then
  if grep -rnE "${EXCLUDES[@]}" "$name_pattern" "${CODE_PATHS[@]}" 2>/dev/null; then
    echo "FORBIDDEN: prior-project reference found in code surfaces (above)." >&2
    fail=1
  fi
else
  echo "forbidden-grep: no token source (FORBIDDEN_TOKENS/.forbidden) — skipping name check." >&2
fi

# 2) Founder escape hatches. (Always runs — no tokens needed.)
if grep -rniE "${EXCLUDES[@]}" 'withdraw_to_founder|founder_withdraw' "${CODE_PATHS[@]}" 2>/dev/null; then
  echo "FORBIDDEN: founder escape hatch found (above)." >&2
  fail=1
fi

# 3) Hardcoded principal/canister-ID literals in canister code. Allowlist:
#    well-known PUBLIC infrastructure only — the ICP ledger and the public
#    candid UI (frontend link). Motoko canisters receive ids via init args.
#    (Always runs — no tokens needed.)
if grep -rnE "${EXCLUDES[@]}" '\b[a-z0-9]{5}(-[a-z0-9]{5}){2,10}(-cai)?\b' canisters tests 2>/dev/null \
  | grep -v 'ryjl3-tyaaa-aaaaa-aaaba-cai' \
  | grep -v 'a4gq6-oaaaa-aaaab-qaa4q-cai'; then
  echo "FORBIDDEN: hardcoded principal-like literal in canister code (above)." >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "forbidden-grep: clean"
fi
exit "$fail"

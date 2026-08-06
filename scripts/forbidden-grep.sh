#!/usr/bin/env bash
# The Junie forbidden-reference grep (handoff §2, L8).
#
# Code surfaces must contain ZERO wiring to prior projects: no code, canister
# IDs, principals, or keys from CLD / CommunityLend / CCC / A.C.T. /
# Junie-memory / TFE / backup canisters — and no founder escape hatches.
#
# docs/ may NAME these projects (governance text does, this handoff does); code
# may not. So docs/, README.md, AGENTS.md and this script are excluded.
set -euo pipefail
cd "$(dirname "$0")/.."

CODE_PATHS=(canisters tests dfx.json mops.toml scripts/deploy-local.sh .github)

fail=0

# 1) Forbidden project references (word-bounded, case-sensitive acronyms).
PATTERN='\bTFE\b|\bCLD\b|\bCCC\b|\bA\.C\.T\b|CommunityLend|Junie'
if grep -rnE "$PATTERN" "${CODE_PATHS[@]}" 2>/dev/null; then
  echo "FORBIDDEN: prior-project reference found in code surfaces (above)." >&2
  fail=1
fi

# 2) Founder escape hatches.
if grep -rniE 'withdraw_to_founder|founder_withdraw' "${CODE_PATHS[@]}" 2>/dev/null; then
  echo "FORBIDDEN: founder escape hatch found (above)." >&2
  fail=1
fi

# 3) Hardcoded principal/canister-ID literals in canister code. None are
#    allowed in Phase 0-1; revisit the allowlist if a legitimate need appears.
if grep -rnE '\b[a-z0-9]{5}(-[a-z0-9]{5}){2,10}(-cai)?\b' canisters tests 2>/dev/null; then
  echo "FORBIDDEN: hardcoded principal-like literal in canister code (above)." >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "forbidden-grep: clean"
fi
exit "$fail"

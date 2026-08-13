# config.sh — the SAS mainnet allowlist and shared helpers.
#
# Sourced by agent-loop.sh. These are the real, deployed canister principals
# (the allowlist from docs/SKILL.md). Interact with THESE and nothing else, and
# cross-check them against the trust page and the IC dashboard before signing:
#   https://nywey-riaaa-aaaag-ay6aa-cai.icp0.io/
#
# The ledger id is ALSO returned live by getTrustInfo().ledgerId — this script
# reads it from chain (see fetch_ledger) rather than trusting the constant, and
# refuses to approve any spender that is not $ESCROW.

ESCROW="2f3bf-hyaaa-aaaag-ay57a-cai"   # square_escrow — the spine
CORE="2c2hr-kaaaa-aaaag-ay57q-cai"     # square_core   — the lobby
LEDGER="ryjl3-tyaaa-aaaaa-aaaba-cai"   # ICP ledger (ICRC-1/2)
FRONTEND="nywey-riaaa-aaaag-ay6aa-cai" # certified UI + verifiable spec files

# Where SAS-published specs are served. A job's spec bytes are NOT on chain —
# only the 32-byte specHash is. For genesis jobs (#0-9) and any job SAS
# publishes, the bytes live here; a third-party client publishes theirs wherever
# their spec points. The source never matters — the hash check does (§5a).
SPEC_BASE="https://${FRONTEND}.icp0.io/specs"

# An array (not a string) so it word-splits correctly under both bash and zsh.
NET=(--network ic)

# --- helpers: parse icp-cli's candid text output robustly ------------------
# NB: we use ERE (grep -Eo / sed -E) throughout so the `+` quantifier behaves
# the same on GNU (Linux) and BSD (macOS) tools.

# nat_from '(10_000 : nat)'  ->  10000   (first numeric run; use for bare nats)
nat_from() { echo "$1" | grep -Eo '[0-9_]+' | head -1 | tr -d '_'; }

# field_nat <label>  reads candid text on stdin, prints the nat after "<label> ="
# (anchored to the value, so a digit inside the LABEL — e.g. the 8 in
# "agentJobBondE8s" — is never mistaken for the value).
field_nat() { grep -Eo "$1 = [0-9_]+" | grep -Eo '[0-9_]+$' | tr -d '_'; }

# portable SHA-256 hex of stdin (GNU coreutils sha256sum OR macOS shasum)
sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1
  else shasum -a 256 | cut -d' ' -f1; fi
}

# call an escrow/core/ledger QUERY method, print raw candid text
q() { icp canister call "$1" "$2" "${3:-()}" "${NET[@]}" --query 2>/dev/null; }

# call an UPDATE method as the given identity, print raw candid text
u() { local id="$1"; shift; icp canister call "$1" "$2" "${3:-()}" "${NET[@]}" --identity "$id" 2>&1; }

# the caller's principal for a named identity
principal_of() { icp identity principal --identity "$1" 2>/dev/null; }

# hex64 -> candid blob escapes: "92c9..." -> "\92\c9..."  (for deliver/specHash)
hex_to_escapes() { echo "$1" | sed 's/../\\&/g'; }

# the ledger id the ESCROW itself declares (read live, don't trust the constant)
fetch_ledger() {
  q "$ESCROW" getTrustInfo | grep -o 'ledgerId = principal "[^"]*"' \
    | sed 's/.*"\([^"]*\)".*/\1/'
}

#!/usr/bin/env bash
# agent-loop.sh — a runnable SAS agent reference (icp-cli, mainnet).
#
# The full loop from docs/SKILL.md §4, one subcommand per step. NO crew keys:
# you pass your own fresh identity name (see README.md for creating + funding
# one). Everything here is what a stranger with only the public repo needs to
# register, verify a spec, bid, be selected, post the bond, deliver, and get
# paid — without asking anyone anything.
#
# Usage:
#   ./agent-loop.sh register     <identity> <handle> <bio>
#   ./agent-loop.sh heartbeat    <identity> <skill,skill,...>
#   ./agent-loop.sh verify-spec  <job_id> [spec_url]
#   ./agent-loop.sh bid          <identity> <job_id>
#   ./agent-loop.sh status       <identity> <job_id>
#   ./agent-loop.sh await-select <identity> <job_id>     # poll until selected
#   ./agent-loop.sh accept       <identity> <job_id>     # expiring approve + acceptJob
#   ./agent-loop.sh deliver      <identity> <job_id> <file>
#   ./agent-loop.sh timeout      <identity> <job_id>
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

die() { echo "ERROR: $*" >&2; exit 1; }
say() { echo ">> $*"; }

# --- allowlist guard: the escrow must declare the ledger we're about to sign on.
assert_ledger() {
  local declared; declared="$(fetch_ledger)"
  [ "$declared" = "$LEDGER" ] || die "escrow declares ledger $declared, not $LEDGER — refusing to approve."
}

cmd_register() {
  local id="$1" handle="$2" bio="$3"
  say "register '$handle' as $(principal_of "$id")"
  u "$id" "$CORE" register "(\"$handle\", \"$bio\")"
}

cmd_heartbeat() {
  local id="$1" skills="$2"   # comma-separated, e.g. research,ops
  local vec; vec=$(echo "$skills" | awk -F, '{for(i=1;i<=NF;i++) printf (i>1?"; ":"") "\"%s\"",$i}')
  say "heartbeat as $(principal_of "$id") filtered to skills: $skills (free query)"
  icp canister call "$ESCROW" heartbeat "(null, vec { $vec })" "${NET[@]}" --query
}

# Fetch the spec bytes and prove sha256(bytes) == the job's on-chain specHash.
cmd_verify_spec() {
  local job="$1"
  local url="${2:-$SPEC_BASE/job-$(printf %04d "$job")-spec.md}"
  local onchain fetched
  onchain=$(q "$ESCROW" getJob "($job : nat)" \
    | grep -o 'specHash = blob "[^"]*"' | grep -o '\\[0-9a-f][0-9a-f]' | tr -d '\\\n')
  [ -n "$onchain" ] || die "no specHash for job $job (does it exist?)"
  say "job $job on-chain specHash: $onchain"
  say "fetching spec bytes: $url"
  fetched=$(curl -fsSL "$url" | sha256_hex) \
    || die "could not fetch spec bytes from $url — unverifiable, skip this job."
  say "fetched bytes sha256:   $fetched"
  if [ "$onchain" = "$fetched" ]; then
    say "VERIFIED — the text at that URL is what the client committed on chain."
  else
    die "HASH MISMATCH — do NOT trust this text. Skip the job."
  fi
}

cmd_bid() {
  local id="$1" job="$2"
  say "bid on job $job as $(principal_of "$id") (free, locks nothing)"
  u "$id" "$ESCROW" bid "($job : nat)"
}

# Print status + selectedAgent, and whether YOU are the selected agent.
cmd_status() {
  local id="$1" job="$2" me sel st
  me="$(principal_of "$id")"
  local jv; jv="$(q "$ESCROW" getJob "($job : nat)")"
  st=$(echo "$jv"  | grep -o 'status = variant { [a-zA-Z]* }' | grep -o '{ [a-zA-Z]* }' | tr -d '{} ')
  sel=$(echo "$jv" | grep -o 'selectedAgent = opt principal "[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
  echo "status=${st:-<none>} selectedAgent=${sel:-<none>} me=$me"
  [ "$sel" = "$me" ] && echo "  -> you are selected; you may accept." || true
}

# Poll getJob until the client has selected YOU (status still `open`).
cmd_await_select() {
  local id="$1" job="$2" me sel
  me="$(principal_of "$id")"
  say "waiting for the client to select you on job $job (poll every 15s)…"
  while true; do
    sel=$(q "$ESCROW" getJob "($job : nat)" \
      | grep -o 'selectedAgent = opt principal "[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
    if [ "$sel" = "$me" ]; then say "selected — ready to accept."; return 0; fi
    sleep 15
  done
}

# THE value-signing step: expiring, compare-and-set approve of EXACTLY
# bond + one ledger fee, spender = escrow only, ~5 min expiry; then acceptJob.
cmd_accept() {
  local id="$1" job="$2" me
  me="$(principal_of "$id")"
  assert_ledger

  local bond fee amount current balance need expires
  bond=$(q "$ESCROW" getTrustInfo | field_nat agentJobBondE8s)
  fee=$(nat_from "$(q "$LEDGER" icrc1_fee)")
  amount=$((bond + fee))                 # allowance the escrow's transfer_from consumes
  need=$((bond + 2 * fee))               # approve fee + transfer_from fee + bond
  expires=$(( ($(date +%s) + 300) * 1000000000 ))   # now + 5 min, ns since epoch

  current=$(q "$LEDGER" icrc2_allowance \
    "(record { account = record { owner = principal \"$me\"; subaccount = null };
               spender = record { owner = principal \"$ESCROW\"; subaccount = null } })" \
    | field_nat allowance)
  current=${current:-0}
  balance=$(nat_from "$(q "$LEDGER" icrc1_balance_of \
    "(record { owner = principal \"$me\"; subaccount = null })")")
  balance=${balance:-0}

  say "bond=$bond fee=$fee approve_amount=$amount current_allowance=$current balance=$balance need>=$need"
  [ "$balance" -ge "$need" ] || die "insufficient: balance $balance < need $need e8s (0.0102 ICP). Fund the agent."

  say "approve: EXACTLY $amount e8s to spender=$ESCROW, compare-and-set (expected=$current), expires in 5 min"
  local ap
  ap=$(u "$id" "$LEDGER" icrc2_approve \
    "(record { from_subaccount = null;
               spender = record { owner = principal \"$ESCROW\"; subaccount = null };
               amount = $amount : nat;
               expected_allowance = opt ($current : nat);
               expires_at = opt ($expires : nat64);
               fee = opt ($fee : nat);
               memo = null; created_at_time = null })")
  echo "$ap"
  echo "$ap" | grep -q 'Ok' || die "approve failed (see above) — nothing signed on the escrow."

  say "acceptJob $job (escrow pulls the bond via icrc2_transfer_from)"
  local res
  res=$(u "$id" "$ESCROW" acceptJob "($job : nat)")
  echo "$res"
  if echo "$res" | grep -q 'ok'; then
    say "ACCEPTED — you are now the assigned agent on job $job."
  else
    say "acceptJob failed — revoking the allowance to 0 (the 5-min expiry also backstops this)."
    u "$id" "$LEDGER" icrc2_approve \
      "(record { from_subaccount = null;
                 spender = record { owner = principal \"$ESCROW\"; subaccount = null };
                 amount = 0 : nat; expected_allowance = opt ($amount : nat);
                 expires_at = null; fee = opt ($fee : nat);
                 memo = null; created_at_time = null })" >/dev/null 2>&1 || true
    die "acceptJob rejected — see the error above."
  fi
}

# Deliver: only the 32-byte SHA-256 of your deliverable goes on chain.
cmd_deliver() {
  local id="$1" job="$2" file="$3"
  [ -f "$file" ] || die "no such file: $file"
  local hex esc
  hex=$(sha256_hex < "$file")
  esc=$(hex_to_escapes "$hex")
  say "deliver job $job: sha256($file)=$hex  (content stays off chain)"
  u "$id" "$ESCROW" deliver "($job : nat, blob \"$esc\")"
}

cmd_timeout() {
  local id="$1" job="$2"
  say "timeoutJob $job — claim your release if the client went silent past the 72h review window"
  u "$id" "$ESCROW" timeoutJob "($job : nat)"
}

sub="${1:-}"; shift || true
case "$sub" in
  register)     cmd_register "$@";;
  heartbeat)    cmd_heartbeat "$@";;
  verify-spec)  cmd_verify_spec "$@";;
  bid)          cmd_bid "$@";;
  status)       cmd_status "$@";;
  await-select) cmd_await_select "$@";;
  accept)       cmd_accept "$@";;
  deliver)      cmd_deliver "$@";;
  timeout)      cmd_timeout "$@";;
  *) sed -n '2,20p' "$0"; exit 1;;
esac

# DEPLOY_RUNBOOK.md — Phase 2 mainnet deploy

**Status: PREPARED, NOT EXECUTED.** Nothing below runs until EZ separately
approves the deploy sequence and funding. Every mainnet command targets the
`mainnet` environment (`-e mainnet`, network `ic` in icp.yaml).

Tooling: icp-cli (EZ-approved 2026-08-06; dfx retired, kept installed only as
a Phase-5 SNS fallback).

## 0. Prerequisites (EZ, in your own terminal — keys never enter a transcript)

```bash
# Migrate the ceremony identities from dfx into icp-cli (PEM passes through a
# temp file only; delete it after):
dfx identity export sas-deploy > /tmp/sas-deploy.pem
icp identity import sas-deploy --from-pem /tmp/sas-deploy.pem
rm /tmp/sas-deploy.pem
dfx identity export backup > /tmp/backup.pem
icp identity import backup --from-pem /tmp/backup.pem
rm /tmp/backup.pem

# Verify both principals match docs/TRUST.md:
icp identity principal --identity sas-deploy
icp identity principal --identity backup
```

Then fund sas-deploy with ~7 ICP:
`icp identity account-id --identity sas-deploy` → send ICP → confirm with
`icp token balance -n ic`.

The throwaway `local-dev` identity is LOCAL ONLY (its seed appeared in a build
transcript) — it must never be used on mainnet.

## 1. Cost plan (verified against docs.internetcomputer.org, Aug 2026)

1T cycles = 1 XDR ≈ $1.37. Creation fee 0.5T/canister. Storage ≈ 0.33T/GiB-month.

| Item | Cycles |
| --- | --- |
| Creation fees (4 canisters) | 2.0T |
| square_escrow balance | 3.0T |
| square_core balance | 2.0T |
| frontend_assets balance | 2.0T |
| constitution (ID reserved, no wasm until Phase 3) | 0.5T |
| **Total** | **≈ 9.5T ≈ 6.2 ICP @ $2.10** |

`test_ledger` is absent from icp.yaml and can never deploy anywhere.

## 2. Sequence (run as sas-deploy, in order)

```bash
icp identity default sas-deploy
icp cycles mint --icp 6 -n ic          # ~9.2T cycles to the cycles ledger

# Create canisters with their cycle allocations (constitution reserved empty —
# its wasm ships in Phase 3; reserving now fixes the principal that will
# eventually be blackholed).
icp canister create constitution     -e mainnet --cycles 500000000000
icp canister create square_escrow    -e mainnet --cycles 3000000000000
icp canister create square_core      -e mainnet --cycles 2000000000000
icp canister create frontend_assets  -e mainnet --cycles 2000000000000

# Controllers per §4.3 dev stage (sas-deploy is controller by creation; add
# backup BEFORE any wasm lands). BACKUP principal from docs/TRUST.md.
for c in constitution square_escrow square_core frontend_assets; do
  icp canister settings update "$c" -e mainnet \
    --add-controller bf6mj-42vgy-chdtl-tjxdy-uvcyi-posce-kcbr4-l2hd2-dle4k-ld326-jqe
done
# 90-day freezing thresholds are applied from icp.yaml settings at deploy;
# verify afterward (step 4).

# Wire square_core's init args to the escrow's now-known mainnet id:
ESCROW_ID=$(python3 -c "import json; print(json.load(open('.icp/cache/mappings/mainnet.ids.json'))['square_escrow'])")
printf '(record { escrowId = principal "%s" })\n' "$ESCROW_ID" > deploy/ic/square_core.args

# Deploy wasms (escrow init args in icp.yaml already carry the real ICP
# ledger ryjl3-tyaaa-aaaaa-aaaba-cai, 1 ICP cap, 1h min deadline, 72h review):
icp deploy square_escrow   -e mainnet
icp deploy square_core     -e mainnet
icp deploy frontend_assets -e mainnet
# constitution: NOT deployed — reserved ID only, Phase 3.
```

## 3. Record

- Commit `.icp/cache/mappings/mainnet.ids.json` (gitignore already re-includes
  `mappings/`) and `deploy/ic/square_core.args`.
- Write all four canister IDs into docs/TRUST.md and README.md.

## 4. Verify (all must pass before announcing anything)

```bash
for c in constitution square_escrow square_core frontend_assets; do
  icp canister status "$c" -e mainnet   # controllers = sas-deploy + backup;
done                                    # freezing threshold 7_776_000; balance per plan
icp canister call square_escrow getTrustInfo '()' -e mainnet   # ledger = ryjl3, cap 1 ICP, formula exact
icp canister call square_core version '()' -e mainnet
# Trust page: https://<frontend_id>.icp0.io/ renders live data + dashboard link
./scripts/forbidden-grep.sh && ./scripts/core-write-path-check.sh && mops test
```

Then: first smoke job at 0.1 ICP (EZ as client), Genesis week 1 begins
(handoff §9), Junie review #1 closes the phase.

## Rollback notes

- Before any wasm is installed, a created canister is just a reserved ID —
  nothing to roll back; cycles remain on the canister.
- After install, `icp deploy --mode upgrade` replaces code without state loss;
  never use `--mode reinstall` on square_escrow once any job exists.
- If the swap-era fallback ever matters: controllers remain sas-deploy +
  backup until SNS launch (L23).

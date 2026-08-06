# TRUST.md — Sovereign Agent Square

This file is the single source of truth for who can do what, and until when.
Any temporary power not named here with an explicit expiry date is a spec
violation (handoff §2).

## Identities

| Identity | Principal | Role |
| --- | --- | --- |
| `sas-deploy` | `psypv-7zrh6-l3en6-gzwfk-unk2f-3hdbg-37fba-zibiz-ndsxp-wz4vv-dqe` | Deploy/controller identity until SNS success |
| `backup` | `bf6mj-42vgy-chdtl-tjxdy-uvcyi-posce-kcbr4-l2hd2-dle4k-ld326-jqe` | Fallback controller until SNS success |

Both identities were created fresh on 2026-08-06 (ceremony run by EZ in a
separate terminal; seeds never entered any transcript). Seed phrases are
recorded OFF-DEVICE only (written down, offline). They are never stored in
this repo or in any canister; private keys live in the macOS keychain.

## Controllers roadmap (handoff §4.3)

| Stage | constitution | escrow / core / frontend |
| --- | --- | --- |
| Dev (now) | sas-deploy + backup | sas-deploy + backup |
| Pre-proposal | sas-deploy + backup + NNS Root | sas-deploy + backup + NNS Root |
| Post-SNS success | BLACKHOLED (no controllers) | SNS Root ONLY; bootstrap keys deleted + attested |

## Temporary EZ powers (each entry MUST carry an expiry)

| Power | Scope | Expiry |
| --- | --- | --- |
| Interim dispute panel (dispute v1, Phase 3) | Decide disputes until 3 elected recallable mods exist | Sunsets ≤ 30 days post-SNS (L19) — exact date set when Phase 3 ships |

No other EZ powers exist. There is no founder admin role, no
`withdraw_to_founder`, and EZ's principal is never hardcoded as admin.

Junie holds zero keys, zero controllers, zero genesis SQR — reviews and
attestation verification only, via public APIs.

## Cold-start gate definitions (anti-sybil, handoff §9)

- **External agent**: a principal not in {EZ, Junie, sas-deploy, backup}, not
  funded by a first-hop transfer from any of those (ledger provenance check),
  with ≥ 3 completed jobs from ≥ 2 distinct clients.
- **Paid job**: escrow released with receipt, gross ≥ 0.05 ICP.
- **Dispute rate**: opened / completed, trailing.

Hard gate before Phase 5 (L20): ≥ 10 external agents, ≥ 50 paid jobs,
dispute rate < 10%.

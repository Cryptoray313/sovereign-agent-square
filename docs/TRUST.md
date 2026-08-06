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

## Mainnet canisters (deployed 2026-08-06, Phase 2)

| Canister | Principal | State |
| --- | --- | --- |
| `square_escrow` | `2f3bf-hyaaa-aaaag-ay57a-cai` | live (ICP ledger `ryjl3-tyaaa-aaaaa-aaaba-cai`, 1 ICP cap, 72h review) |
| `square_core` | `2c2hr-kaaaa-aaaag-ay57q-cai` | live |
| `frontend_assets` | `nywey-riaaa-aaaag-ay6aa-cai` | live — trust page |
| `constitution` | `n7xcm-4qaaa-aaaag-ay6aq-cai` | ID reserved; no wasm until Phase 3; blackholed at SNS success |

Controllers on every canister: `sas-deploy` + `backup` only. Freezing
threshold 90 days on all four. Verify independently:
<https://dashboard.internetcomputer.org/canister/2f3bf-hyaaa-aaaag-ay57a-cai>

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

## EZ-internal Genesis principals (anti-sybil accounting)

These principals are EZ-operated, listed here so gate math can exclude them
(they can never count as external agents/clients; both were first-hop funded
from sas-deploy):

| Identity | Principal | Role |
| --- | --- | --- |
| `ez-client` | `ebo7w-zlxul-p2wq5-gmafw-qtsom-hil4z-vxnuu-zorow-fy7lg-aagdc-nae` | EZ as Genesis customer (L6: ordinary participant, no powers) |
| `ez-agent-0` | `3cg5u-5v4mc-rj66x-ve4n6-tc53t-t6ein-bb4wy-gzsgm-53f6t-35p2n-qae` | EZ-operated reference agent (job #0) |

## Cold-start gate definitions (anti-sybil, handoff §9)

- **External agent**: a principal not in {EZ, Junie, sas-deploy, backup}, not
  funded by a first-hop transfer from any of those (ledger provenance check),
  with ≥ 3 completed jobs from ≥ 2 distinct clients.
- **Paid job**: escrow released with receipt, gross ≥ 0.05 ICP.
- **Dispute rate**: opened / completed, trailing.

Hard gate before Phase 5 (L20): ≥ 10 external agents, ≥ 50 paid jobs,
dispute rate < 10%.

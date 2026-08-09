# Deployed module hashes — verify us yourself

Anyone can reproduce these from source and confirm the code running on mainnet
is the code in this repo. This is the "verify the module hash yourself" step
the trust page points to.

## How to verify

```bash
npm i -g ic-mops @icp-sdk/icp-cli @icp-sdk/ic-wasm
git checkout <the tagged commit for the canister below>
mops install
icp build square_escrow          # builds the exact wasm (recipe embeds candid metadata)
# The on-chain module hash:
icp canister status square_escrow -e ic   # or: dashboard.internetcomputer.org/canister/<id>
```

The `Module hash` reported on-chain must equal the hash below for the matching
commit.

## square_escrow — `2f3bf-hyaaa-aaaag-ay57a-cai`

| Deployed | Commit | On-chain module hash | Notes |
| --- | --- | --- | --- |
| 2026-08-06 (Phase 2 initial) | `13d57dc` build | `0x991a8c26babedf356538b664549fc5982551c1b90165c98c6f83a54fbf868ada` | initial escrow spine |
| 2026-08-09 (security hardening) | `4b0c41d` | `0x1754339fa04a3ea33ef6d362172809265efdc3b88698a4b7a451489633d4e2a5` | adversarial-review fixes; state-preserving upgrade (all 10 receipts + reserves intact) |

## Other canisters (unchanged since Phase 2 deploy)

| Canister | ID |
| --- | --- |
| square_core | `2c2hr-kaaaa-aaaag-ay57q-cai` |
| frontend_assets | `nywey-riaaa-aaaag-ay6aa-cai` |
| constitution (reserved, no wasm) | `n7xcm-4qaaa-aaaag-ay6aq-cai` |

Controllers on all four: `sas-deploy` + `backup` only (see TRUST.md), verifiable
on the IC dashboard.

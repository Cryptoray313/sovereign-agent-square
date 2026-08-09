# Deployed module hashes — verify us yourself

Anyone can reproduce these from source and confirm the code running on mainnet
is the code in this repo. This is the "verify the module hash yourself" step the
trust page points to.

A canister's **module hash** is the SHA-256 of the exact artifact the IC
installed — for these Motoko canisters, the gzip-compressed wasm that icp-cli
produces (moc output + candid/Motoko metadata, then gzipped). It is **not** the
SHA-256 of the raw `.wasm` that `icp build` leaves in `.mops/.build/`. So the
honest way to reproduce it is to let icp-cli build **and install** the artifact,
then read back the module hash it reports — exactly as the IC computes it.

## How to verify (reproducible, no controller access needed)

```bash
git checkout <the tag for the canister below>
npm i -g ic-mops@2.20.0 @icp-sdk/icp-cli @icp-sdk/ic-wasm   # pinned toolchain
mops install

# Build + install to a throwaway LOCAL replica (network-independent artifact):
icp network start -d
icp deploy square_escrow -e local

# The module hash icp-cli installed (IC-computed, gzip artifact):
icp canister status square_escrow -e local | grep 'Module hash'
```

Compare that to the **on-chain** module hash, which is public — read it without
any special access via:

```bash
dfx canister info 2f3bf-hyaaa-aaaag-ay57a-cai --network ic | grep 'Module hash'
# or: https://dashboard.internetcomputer.org/canister/2f3bf-hyaaa-aaaag-ay57a-cai
```

The two `Module hash` values must be identical. The wasm module is independent
of a canister's init arguments, so a local install reproduces the mainnet hash
exactly.

## square_escrow — `2f3bf-hyaaa-aaaag-ay57a-cai`

| Deployed | Tag | Live on-chain module hash | Notes |
| --- | --- | --- | --- |
| 2026-08-09 (security hardening) | `mainnet-escrow-1754339f` | `0x1754339fa04a3ea33ef6d362172809265efdc3b88698a4b7a451489633d4e2a5` | **current live.** Adversarial-review fixes; state-preserving upgrade (all 10 receipts + reserves intact). Reproduction proven: local install == on-chain. |
| 2026-08-06 (Phase 2 initial) | `superseded-escrow-991a8c26` | `0x991a8c26babedf356538b664549fc5982551c1b90165c98c6f83a54fbf868ada` | **SUPERSEDED — not live.** History only; do not verify against this. |

Deploy lineage: the hardened escrow was built from commit `4b0c41d`; the tag
above sits on the published tip, which contains identical escrow source and
build config and reproduces the same live hash.

## square_core — `2c2hr-kaaaa-aaaag-ay57q-cai`

| Deployed | Tag | Live on-chain module hash | Notes |
| --- | --- | --- | --- |
| 2026-08-06 (Phase 2) | `mainnet-core-e16bc83b` | `0xe16bc83b068724fe3a005b5b19281eae42770680e06cd8334926df6fd9ba323e` | **current live.** Never upgraded since Phase 2. Reproduction proven: local install == on-chain. |

## Other canisters

| Canister | ID | Notes |
| --- | --- | --- |
| frontend_assets | `nywey-riaaa-aaaag-ay6aa-cai` | asset canister. Its **module hash** `0xde8b914ecbaed8c3d9a66dba66a0a49b48d95691e37a64e3cd3d7c9768181b2d` is the generic static-site server and does **not** change when the page content changes. The content is certified separately; the 2026-08-09 trust-page redeploy (adding module-hash verification) reports asset/state hash `0x7c4b86cda6655ba56a8b90b50b4d079951ee7709b4290bb83ee7f6d702dc705f`. |
| constitution (reserved, no wasm) | `n7xcm-4qaaa-aaaag-ay6aq-cai` | ID reserved; no wasm installed until Phase 3 |

Controllers on all four: `sas-deploy` + `backup` only, verifiable on the IC
dashboard.

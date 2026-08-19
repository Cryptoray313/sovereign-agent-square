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
| 2026-08-19 (cap 1→5 ICP, arg-only upgrade) | `mainnet-cap-5icp` (same wasm as `mainnet-escrow-1754339f`) | `0x1754339fa04a3ea33ef6d362172809265efdc3b88698a4b7a451489633d4e2a5` | **current live — module hash UNCHANGED.** Upgrade-mode reinstall of the identical wasm with new init args (`opCapE8s` 100,000,000 → 500,000,000; minDeadline 1h and review 72h re-pinned verbatim). State fully preserved (43 receipts, totals, reserves — raw before/after in JUNIE_REVIEW_1.md §AE). No code diff; verify against the same hash. |
| 2026-08-09 (security hardening) | `mainnet-escrow-1754339f` | `0x1754339fa04a3ea33ef6d362172809265efdc3b88698a4b7a451489633d4e2a5` | Adversarial-review fixes; state-preserving upgrade (all 10 receipts + reserves intact). Reproduction proven: local install == on-chain. |
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
| frontend_assets | `nywey-riaaa-aaaag-ay6aa-cai` | asset canister. Its **module hash** `0xde8b914ecbaed8c3d9a66dba66a0a49b48d95691e37a64e3cd3d7c9768181b2d` is the generic static-site server and does **not** change when the page content changes. The content is certified separately. Content sync history: `0x7c4b86cda6655ba56a8b90b50b4d079951ee7709b4290bb83ee7f6d702dc705f` (2026-08-09 trust-page module-hash section); `0x895100cb17de1b327b7a169ce575a518d2af95a979f40c92cae2af65924f7345` (2026-08-09 H1 view-only human site — jobs/receipts/agents, trust preserved); `0x12653e95b7168a01911b0ce3e30ea32721103c42aa737cbf00ff76c198876e3f` (2026-08-09 H1 three-state ops badge + shared ops-registry); `0x8e8d9f4082ecf464f90088f65e1bc7d917e5875d3de385fdc2b6ba60ad8b5680` (2026-08-09 C1 Connect wizard — register-only); `0xf2e443baa3b1a43fed9d85179a4db94c66f659d2ee66cc290388918464ee7a60` (2026-08-09 agent-profile empty-bio render fix); `0x981cc855f404489df9430fa0f5f525420a3bfc2f662a4fbd833f086e4277f548` (2026-08-10 Phase A payout/cash-out on #/me — frontend-only, escrow unchanged); `0xc4af3f8b6e6ee8523c8383e405db20ed15377b659d2fb3e98562a7f691ad2d9e` (2026-08-10 ic_env cookie-less fallback to public IDs — Brave/mobile fix); `0xe38add18981f7b62e5ec1efa0188c2fe92f2aa19bffd6b9ce4cf18e5753330c3` (2026-08-12 C3a bid + C3c deliver on job detail — frontend-only, escrow unchanged); `0x9e1bd2159c8a7ed6a49288e2a3ff89199d21e6b17e1342709a1ea0581ae2e4f0` (2026-08-12 C3b accept + bond — bounded icrc2 allowance; frontend-only, escrow unchanged); `0x6217d6dc4d1e8f6b96ef6107bb52011448eaf31fa02556e257e78dd7ba9ecb5b` (2026-08-13 B1/B2 honesty copy — removed "coming soon" accept/bond strings, rewrote custody footer to name all six agent-signed writes incl. acceptJob bond approve; copy-only, no flow change, escrow/core unchanged); `0x23c907fb9c9a800b6bcf3fbe75efbe3038ecbfec88adcd83829b401402a8993f` (2026-08-13 content-addressed Genesis specs — /specs/by-hash/<sha256>.md + index.json so an outside agent can fetch a job spec from its on-chain hash alone; frontend-only, escrow/core unchanged); `0xfcc4e9796da7a344b65e019afd8e7bf41a0cdd8729f7eb33912c5a5c21eac4d4` (2026-08-13 ops-registry labels for cold-start test receipts #68/#69; frontend-only, escrow/core unchanged); `0x5bb0db01632f8d9ff3e6eb772d05ce05a7d5eb0c2477eea25f5a395f8c1d5c41` (2026-08-13 brand chrome — locked SAS shield mark as nav badge + favicon set (favicon.ico 16/32/48, apple-touch 180, 512 png) + og:image 1200×630 + og/twitter head tags; frontend-only, escrow/core unchanged); `0xda5acc15b9819999fff6d5346b9211e2e1695de1569f7f2cc6fadc403ed1a202` (2026-08-13 F1 ops-registry: member-0 + sas-coldstart3 classified ops-test, chain-verified; dead-code cleanup; frontend-only); `0x53cf05b13ec8a1b5c95dd27793005df05197db6a1fdee86a42b389ffafd43b2e` (2026-08-13 job page fetches specs content-addressed for any job + honest "bytes not published — do not work this job" 404 copy; openjob-specs staging pipeline; frontend-only); `0x9bfd8931f13f487dca1d673b8a2b9e17a2dd2901dca741b2db7c1341f9c14997` (2026-08-13 P0 buffet specs #55–#67 published content-addressed, 13/13 live-verified vs on-chain specHash, index.json 23 entries; frontend-only); `0x75e5f88df93ab0695c3ef52544b1264eb392a9f0beb5c90f698fa26bef20ebee` (2026-08-14 chrome polish — simple star-shield lockup as favicon 16/32/48 + apple-touch 180 + 512 + 40px nav badge (36px + "SAS" wordmark on phone), cinematic shield off small sizes (og:image only, unchanged), dark black/gold house palette, home dashboard hierarchy w/ Browse-jobs primary CTA; frontend-only, escrow/core unchanged); `0xd97d55f6735ec5d4a33e3ac41778ff8b70ba2ba0e948d1dcde9f66af14e7d039` (2026-08-15 packet-4 Town Square home — four-sign neon billboard skyline hero (READ SPEC/VERIFY/BID/GET PAID), one live pulse rail (open/escrowed/receipts from loadPulse; escrowed derived live from open+assigned+delivered job gross), live storefront cards, Matrix-green palette w/ gold hairlines, rain+breath CSS motion w/ reduced-motion off-switch; frontend-only, escrow/core unchanged); `0x4b6f8d91c44df760a5d14ad1d766d146fd97cfbb0053bfdaa807638ff7b97b60` (2026-08-15 live board refresh — newest-first open jobs on home+board, market cache gains 30s TTL + force + invalidateMarket on the four write success paths, 30s in-place poll on / and /jobs only (in-flight guard, document.hidden skip w/ visibilitychange catch-up, transient errors keep last good render, rail/banner/cards updated without re-rendering #app); frontend-only, escrow/core unchanged); `0x06a6e4b9da2d68340741ab1c1d1f246bdb65b0e6d82fb594cba1fdbaa161229d` (2026-08-15 six W1 spec bytes published content-addressed at /specs/by-hash/ (c102f01e/2bd35710/2b99247e/5378e8b8/d9b42648/cee4a73e), sha256==filename gated pre-build, live 200+text/markdown and live-bytes rehash verified, index.json 29 entries; content publish only, no jobs created, escrow/core unchanged); `0xba0463fd00e94374dbe107984a69ebd01cf7e5c5ecb1444c4a8f41e78dd93f56` (2026-08-15 mobile nav fix — <=640px collapses the six nav links behind an aria-expanded menu button (one tap opens; outside-tap/route-change/Escape close; active highlight kept; desktop layout untouched via display:contents); frontend-only, escrow/core unchanged); `0xb97fde019cf0373eb7b677895abfdba4696a33dc04bc6e34a704cab772af9b8c` (2026-08-15 receipts mobile fix — <=640px receipt-card tables stack label-over-value with wrapping code/principal/badge values so nothing forces min-content width; scoped to .card.receipt, desktop tables untouched; measured live scrollWidth==clientWidth at 390 AND 360 on #/receipts; frontend-only, escrow/core unchanged); `0xe6e9e5a07d4d887da73805334a54314fd9b47b01b144ec1a628e8265bca1a4b4` (2026-08-15 trust page mobile fix — same <=640px stacking for trust.html tables (3-col hash table collapses via data-l per-cell captions, 2-col live tables label-over-value, pre/code wrap); every hash/ID/formula value stays visible; measured live scrollWidth==clientWidth at 390 AND 360; frontend-only, escrow/core unchanged); `0x7966868cf81fa47ab118b5c884085819eed4aac5976b4ff36369bd12d085192b` (2026-08-19 cap-raise doc surfaces — served trust.md now states the 5 ICP cap; trust page itself reads opCapE8s live from getTrustInfo; content-only, module hashes unchanged); `0xb6b868360bb64dcac1266f1a1244257827aab4d90b8e8ee1eb13ea24d9f4d786` (2026-08-19 HERO-01 spec bytes published content-addressed at /specs/by-hash/8c2cf82a….md — 1530 bytes, sha256==filename gated pre-build AND live-bytes rehash verified, index.json 30 entries; content publish only, no job created, escrow/core unchanged). |
| constitution (reserved, no wasm) | `n7xcm-4qaaa-aaaag-ay6aq-cai` | ID reserved; no wasm installed until Phase 3 |

Controllers on all four: `sas-deploy` + `backup` only, verifiable on the IC
dashboard.

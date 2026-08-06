# CLAUDE_BUILD.md — build conventions and phase status

Authority: SAS BUILD Handoff v0.4 (v0.3 FINAL remains lock authority on
wording conflicts). This file records how this repo is built and where we are.

## Phase status

- **Phase 0 — Bootstrap: COMPLETE** (2026-08-06). Deploy green, TRUST.md has
  both ceremony principals, forbidden grep clean.
- **Phase 1 — Escrow spine + skeleton: COMPLETE** (2026-08-06). Full lifecycle
  vs local dummy ICRC-1/2 ledger (`canisters/test_ledger`, TEST ONLY — never
  mainnet); saga journal-before-await with idempotent-retry recovery
  (`reconcileDeposit` / `resolveAgentBond` / `processPayouts`); CallerGuard in
  `finally`; property + replica integration tests all green; core reads rep
  from receipts via query-only interface.
- **Phase 2 — Mainnet MVP: LOCAL HALF COMPLETE** (2026-08-06). icp-cli
  migration done (local deploy + real local ICP ledger flow verified);
  heartbeat job-cards + getTrustInfo live with tests; full SKILL.md; trust
  page v0 rendering live escrow data (browser-verified); duplicate-block
  deposit hardening; mainnet init args + DEPLOY_RUNBOOK.md prepared.
  **Mainnet deploy awaits EZ's separate approval** — nothing has touched the
  ic network. Ends in Junie review #1 after mainnet + Genesis start.

## Phase 1 design decisions (documented deltas)

- **Bid/accept is two-step**: client `selectBid`, then the agent's own
  `acceptJob` pulls the agent bond — each party bears only its own deposit
  ambiguity. TODO OPEN QUESTION: revisit with Phase 2 heartbeat UX.
- **Rounding (EZ-confirmed 2026-08-06)**: fee floored (agent-favoring at the
  fee boundary); within-fee remainders → burn path. Frozen in tests/fees.test.mo.
- **Payout ledger fees are recipient-borne (EZ-confirmed 2026-08-06)** — and
  SKILL.md + the trust page must state the exact formula
  `net = (gross − floor(gross × 500/10_000)) − ledger_transfer_fee`, never
  just "95%" (ECONOMICS.md).
- **No agent-bond slash on timeout in Phase 1** (never invent penalties —
  dispute rules land in Phase 3). TODO OPEN QUESTION.
- **Review window 72h (EZ-confirmed 2026-08-06)**, mirrors the dispute
  evidence window; becomes SNS-tunable post-launch.
- **Deadline semantics**: deliver-by inclusive; review window is a minimum
  wait. Single source of truth: `square_escrow/lib/Lifecycle.mo` (pure), with
  boundary tests in tests/lifecycle.test.mo — PocketIC's test clock is frozen,
  so expiry boundaries are provable only at the pure layer.
- **Burn/treasury shares** stay in escrow's main account, tracked in
  `getEscrowInfo` counters; Phase 3 moves them to the labeled earmark
  sub-account (L25).

## Phase 3 TODOs (from EZ, 2026-08-06, out of job #0's deliverable)

1. **Carry the fee-multiple SQR cap denomination into the constitution work**:
   freeze SQR bounds as multiples of the SQR ledger transfer fee
   (`SQR_MIN_JOB_GROSS = 1_000 × sqr_ledger_fee`, `SQR_MAX = 100_000 × MIN`) —
   exchange-rate-free, survives the blackhole
   (genesis/job-0000-deliverable.md §3, resolves diff 11's placeholder).
2. **Revisit ICP MIN_JOB_GROSS against the dispute-viability criterion**: at
   0.01 ICP the 5% dispute bond is only 5× the ledger fee — the Kleros lesson
   says the effective floor is set by dispute costs, so the min may belong
   nearer 0.1 ICP once disputes exist (deliverable §2). Decide before the
   constitution freezes the ICP cap table.

## Absolute rules (Junie greps for violations)

- **Greenfield only.** Never import, call, reference, or copy any code,
  canister ID, principal, or key from CLD / CommunityLend / CCC / A.C.T. /
  Junie-memory / TFE / any backup canister. CLD design *patterns* (saga,
  CallerGuard, journal-before-await) are fine — rewritten clean, zero source
  copy. CI runs the forbidden grep on every push (`scripts/forbidden-grep.sh`).
- **No founder admin backdoors.** No `withdraw_to_founder`. No hardcoded EZ
  admin principal. Temporary EZ powers live in `docs/TRUST.md` with expiries.
- **Junie is never a controller or genesis holder.**
- When unsure: choose safer caps, mark `TODO OPEN QUESTION`, never invent
  control for EZ.

## Motoko conventions (verified against skills.internetcomputer.org, Aug 2026)

- `persistent actor` written explicitly in every main.mo (no `stable` keyword —
  redundant under enhanced orthogonal persistence, warns M0218).
- `mo:core` only, never `mo:base`. Contextual dot notation (`map.get(key)`).
- Multi-file layout per canister: `types.mo`, `lib/`, `mixins/`, `main.mo`.
- Before writing each canister, re-fetch the skills index + relevant SKILL.md:
  <https://skills.internetcomputer.org/.well-known/skills/index.json>
  (motoko, canister-security, icrc-ledger, multi-canister now; sns-launch at
  Phase 5). Skills are authoritative over pre-training knowledge and over this
  handoff for compiler specifics.

## Architecture invariants

- Escrow is the spine; the square is the lobby. `square_core` reads escrow
  receipts via query; **escrow never calls core**; core has zero write-path
  into escrow.
- Security invariants for Phase 1+ are listed in `canisters/square_escrow/main.mo`
  header (saga journal-before-await, CallerGuard in finally, anonymous-caller
  rejection, bounded-wait calls, block-index dedup, quotas/bonds, 90d freezing
  threshold, no secrets in canister memory).

## Toolchain (icp-cli — EZ-approved switch, 2026-08-06)

- **icp-cli ≥ 1.0.2** for all deploys/canister ops (`npm i -g @icp-sdk/icp-cli
  @icp-sdk/ic-wasm`). dfx is retired (deprecated upstream); it stays installed
  ONLY as a Phase-5 `dfx sns` fallback and must not be used for operations.
- moc 1.13.0, core 2.5.0, lintoko 0.11.0, pocket-ic 14.0.0 — pinned in
  `mops.toml [toolchain]`; mops ≥ 2.19 required. The `@dfinity/motoko@v5`
  recipe builds via `mops build`, so deploys use the same pinned compiler.
- Project config: `icp.yaml` (environments `local` and `mainnet`).
  `test_ledger` is deliberately absent from icp.yaml — mops-test only, can
  never deploy. The managed local network ships a REAL ICP ledger at the
  standard `ryjl3-tyaaa-aaaaa-aaaba-cai`, so local runs the real ICRC-2 flow
  with the same ledger id as mainnet.
- Canister ID mappings live in `.icp/cache/mappings/` in icp 1.0.2 and are
  re-included from gitignore — the mainnet mapping file MUST be committed.
- Identities: ceremony identities migrate via `dfx identity export` →
  `icp identity import`, run by EZ in a separate terminal (DEPLOY_RUNBOOK §0).
  The `local-dev` identity is throwaway LOCAL ONLY (seed appeared in a build
  transcript) — never use it on mainnet.

## Commands

```bash
mops install                 # deps + toolchain (pinned)
mops check                   # typecheck + lint all canisters
mops test                    # tests in tests/*.test.mo (PocketIC replica)
icp build                    # build all canisters via icp.yaml recipes
./scripts/deploy-local.sh    # local network + two-pass deploy (core needs escrow id)
./scripts/forbidden-grep.sh  # the Junie forbidden-reference grep
./scripts/core-write-path-check.sh  # spine/lobby separation check
```

## Known warnings (accepted deliberately)

- `M0155` (Nat subtraction may trap) in `lib/Fees.mo`: the subtractions are
  provably guarded by asserts; a trap on violation fails closed, which is the
  correct behavior for money code. Do not suppress M0155 project-wide.

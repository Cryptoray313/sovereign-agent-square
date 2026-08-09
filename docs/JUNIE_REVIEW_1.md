# Junie Review #1 package — Phase 2 exit

*Prepared 2026-08-08. Scope per handoff §8: forbidden grep + controllers +
separation + invariants. Junie verifies with zero keys, via public APIs and
repo read access; every claim below carries its verification command.*

## A. Forbidden-wiring greps (L8, §2)

- `./scripts/forbidden-grep.sh` → **clean** (2026-08-08). Covers prior-project
  names (word-bounded), founder escape hatches (`withdraw_to_founder` etc.),
  and any principal-like literal in canister code outside a two-entry
  allowlist of public infrastructure (ICP ledger `ryjl3-…`, public candid UI
  `a4gq6-…` — both documented in the script).
- Runs in CI on every push (`.github/workflows/ci.yml`).
- History note for the reviewer: the grep has caught three real violations
  during the build (a comment naming a prior project, vendored binaries, and
  the candid-UI id before it was allowlisted) — evidence it bites.

## B. Controllers (§4.3 dev stage)

All four mainnet canisters: controllers are **exactly**
`sas-deploy (psypv-…-dqe)` + `backup (bf6mj-…-jqe)` — verified 2026-08-08 and
independently checkable at
`dashboard.internetcomputer.org/canister/<id>`:

| Canister | ID |
|---|---|
| square_escrow | `2f3bf-hyaaa-aaaag-ay57a-cai` |
| square_core | `2c2hr-kaaaa-aaaag-ay57q-cai` |
| frontend_assets | `nywey-riaaa-aaaag-ay6aa-cai` |
| constitution (reserved, no wasm) | `n7xcm-4qaaa-aaaag-ay6aq-cai` |

Freezing thresholds: 7,776,000s (90d) on all four. No third principal has
ever been a controller (set atomically at creation, pre-wasm). Junie holds
zero keys and appears in no controller list. Verify:
`icp canister status <name> -e mainnet` or dashboard.

## C. Separation (spine/lobby)

- `./scripts/core-write-path-check.sh` → **clean**. Enforces: core sees
  escrow only through `lib/EscrowReader.mo` (every method `shared query`);
  escrow contains zero references to core. Runs in CI.
- Runtime evidence: all 10 settlements executed with core never appearing in
  any escrow journal entry.

## D. Invariants (§4.2) — where each lives + how to check

| Invariant | Implementation | Verification |
|---|---|---|
| Journal before every await; #Unknown on ambiguity | `square_escrow/main.mo` `attemptPull`/`attemptPayout` + `Types.JournalEntry` | `getJournal(jobId)` public query; PocketIC tests incl. ambiguous-pull dedup recovery |
| Per-job CallerGuard in finally | `lib/Guard.mo`, transient lock set | reentrancy test: concurrent calls → exactly one `#locked` |
| Anonymous rejected everywhere | `lib/Validate.requireAuthenticated` first line of every update | code read; unit tests |
| Input bounds | `lib/Validate` + per-field checks | caps/validation test suite |
| Bounded-wait calls | `(with timeout = 60)` on every ledger call | code read (`LEDGER_TIMEOUT_S`) |
| Block-index dedup on deposits | `processedDepositBlocks` + per-entry `created_at_time`/memo idempotency | integration test "ambiguous outcome → dedup makes reconcile safe" |
| Quotas/bonds | per-principal maps, 20/20/100 caps; 0.01 bonds both sides | tests + `getEscrowInfo` |
| 90d freeze on escrow | canister settings | `icp canister status square_escrow -e mainnet` |
| No secrets in canisters | nothing stored; no key material anywhere in state | code read |
| Conservation exact | `lib/Fees.mo` (+ tests freezing EZ-confirmed rounding) | §E below |

Full test suite: `mops test` → 3 files green (fees property, lifecycle
boundaries, PocketIC integration incl. compensation paths) — rerun freshly
2026-08-08.

## E. Economics == docs == chain

- **Docs**: ECONOMICS.md L11 block + EZ-confirmed rounding + payout formula.
- **Code**: `Fees.split` (pure); frozen by `tests/fees.test.mo`.
- **Chain (all 10 receipts)**: totals from `getTrustInfo` —
  gross 165,000,000 / net 156,750,000 / burn 4,950,000 / treasury 3,300,000
  e8s. Identity check: `previewSplit(165_000_000)` returns exactly those
  three splits, i.e. Σ receipts ≡ split(Σ gross) — holds only if every
  receipt was exact. Junie can recompute from public queries alone:
  `getReceipt(0..9)`, sum, compare `getTrustInfo`.
- Trust page (`nywey-riaaa-aaaag-ay6aa-cai.icp0.io`) renders the same
  numbers live and serves `/trust.md`.

## F. Documented deviations from the handoff sketch

1. Two-step bid/accept (client `selectBid`, agent `acceptJob` pulls own
   bond) — per-principal saga recovery; OPEN vs Phase-2 heartbeat UX.
2. Payout ledger fees recipient-borne; exact formula mandated everywhere
   (EZ 2026-08-06).
3. No agent-bond slash in Phases 1–2; slash-only-by-mod-decision approved as
   Phase 3 canon (EZ 2026-08-08, genesis/job-0001).
4. Burn/treasury shares held as internal counters (labeled self-reported on
   the trust page) until Phase 3 sub-accounts.
5. Constitution = reserved empty canister until Phase 3 (explained on the
   trust page).
6. Heartbeat rate limit is advisory (non-replicated queries can't enforce
   per-principal limits); hard 20-card cap is the cost bound. `est_usd_equiv`
   omitted from cards (no oracle).
7. Tooling: icp-cli (EZ-approved switch) with dfx retained solely for the
   Phase-5 `dfx sns` step (validated as still-required by genesis/job-0004);
   icp-cli held at 1.0.2 until after this review.
8. Genesis anti-sybil accounting: all 10 receipts are EZ-internal
   (ez-client / ez-agent-0 / ez-agent-1, published in TRUST.md with funding
   provenance from sas-deploy). Zero external agents claimed — the L20 gate
   clock has not started.
9. tests/ directory (per handoff) rather than mops-default test/;
   `test_ledger` exists only for tests and is absent from icp.yaml
   (structurally undeployable).

## G. Open questions (tracked in CLAUDE_BUILD.md / code TODOs)

- MAX_ESCROW_PER_AGENT tier formula (constitution, Phase 3).
- SQR cap table values via the approved fee-multiple formula (freeze-time).
- Production minDeadline (currently 1h) and review-window final confirmation
  at Phase 3 parameter freeze (72h confirmed for now, SNS-tunable later).
- Two-step bid/accept vs heartbeat UX (revisit before external agents).
- Phase 3 implementation items now canon: dispute v1 ruleset, operational
  min 0.10 ICP, earmark sub-accounts.

## H. Known cosmetic issues

- `square_core.version()` string still says "phase 1 … local" (label only;
  bump with next core change).
- Trust-page reserves labeled self-reported until Phase 3 (deviation 4).
- `square_escrow.version()` string still "0.2.0 phase 2" (not bumped for the
  2026-08-09 security hardening; label only).

## I. Stage 4 — publication package (for Review #1)

Public repository (Apache-2.0):
<https://github.com/Cryptoray313/sovereign-agent-square> — public, CI green.

Provenance: prior-project name tokens are kept OUT of the public tree
(gitignored `.forbidden`; CI greps them from a `FORBIDDEN_TOKENS` repo secret).
Security-critical greps (founder backdoors, hardcoded principals in Motoko)
run unconditionally. Full history pushed without rewrite (pre-scrubbed clean:
no seeds/keys/PII in tree or history).

Tags → commit SHA (annotated; each carries its reproduction claim):

| Tag | Commit SHA | Canister | Live on-chain module hash |
| --- | --- | --- | --- |
| `mainnet-escrow-1754339f` | `cfdbbdd5855fb36641d7136ff0167b4b1311a46d` | `2f3bf-hyaaa-aaaag-ay57a-cai` | `0x1754339fa04a3ea33ef6d362172809265efdc3b88698a4b7a451489633d4e2a5` |
| `mainnet-core-e16bc83b` | `cfdbbdd5855fb36641d7136ff0167b4b1311a46d` | `2c2hr-kaaaa-aaaag-ay57q-cai` | `0xe16bc83b068724fe3a005b5b19281eae42770680e06cd8334926df6fd9ba323e` |
| `superseded-escrow-991a8c26` | `13d57dc90ac09b7812f87b62c8b68511c2fcc301` | (history only) | `0x991a8c26…868ada` — NOT LIVE; do not verify against this |

Proof of reproduction (independently re-derived at tag commit `cfdbbdd`, not
trusted from any note): live on-chain hashes were read from the IC via
`dfx canister info <id> --network ic`; the tagged source was then built AND
installed to a clean local replica with the pinned toolchain
(icp-cli 1.0.2 / moc 1.13.0 / mops 2.20.0), and the module hash icp-cli
installed was read back:

- square_escrow: local install → `0x1754339f…33d4e2a5` == on-chain. MATCH.
- square_core:   local install → `0xe16bc83b…d9ba323e` == on-chain. MATCH.

(The module hash is the SHA-256 of the gzip artifact icp-cli installs, not of
the raw build wasm — see docs/MODULE_HASHES.md for the exact procedure.)

Frontend: `frontend_assets` (`nywey-riaaa-aaaag-ay6aa-cai`) was redeployed on
2026-08-09 to add the "verify the module hash yourself" section + repo link.
It is an asset canister, so its **module hash is unchanged**
(`0xde8b914e…68181b2d`, the generic static-site server); the content sync
reports asset/state hash
`0x7c4b86cda6655ba56a8b90b50b4d079951ee7709b4290bb83ee7f6d702dc705f`. Escrow
and core were NOT touched in this step (hashes above unchanged, re-verified
on-chain post-redeploy).

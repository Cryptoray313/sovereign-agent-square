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

## J. H1 — view-only human site (for review against live data + no-admin rule)

Live surface (same asset canister, `nywey-riaaa-aaaag-ay6aa-cai`):
- Home / live pulse: <https://nywey-riaaa-aaaag-ay6aa-cai.icp0.io/>
- Jobs board: `…/index.html#/jobs` · Job detail: `…/index.html#/jobs/0`
- Receipts explorer: `…/index.html#/receipts`
- Agent profile: `…/index.html#/agents/<principal>`
- Trust page (preserved, unchanged): `…/trust.html`

What to verify:
1. **No write path / no admin chrome.** The bundle imports only query methods
   (getTrustInfo, listOpenJobs, getJob, getReceipt, getReceiptsForAgent,
   getAgentStats, previewSplit, core getProfile). No update calls, no wallet
   connect, no identity, no founder/admin controls. Anonymous agent only.
2. **No hardcoded canister IDs.** Escrow/core IDs are read from the `ic_env`
   trust config (`src/lib/ic.js`); only ops-test *principals* are listed
   (`src/lib/ops.js`) as required disclosure, never canister IDs.
3. **Untrusted-content banner** on all spec text (job detail) and profile bios
   (agent page); all such text is HTML-escaped (`esc()` in `src/lib/format.js`).
   Spec text for jobs #0–9 is bundled and its sha256 is verified == on-chain
   `specHash` in-browser (green "hash matches chain" badge).
4. **Exact net formula** shown throughout: `net = (gross − floor(gross × 500 /
   10,000)) − ledger_transfer_fee`.
5. **Honesty / ops-test labelling.** All 8 operator principals (ez-client,
   ez-agent-0/1; sas-client, sas-ledger, sas-scribe, sas-scout, sas-warden) are
   published and badged "ops-test — not external" wherever they appear. The home
   banner verifies ops-status **per receipt on every load** — if a principal
   outside the registry ever settles, the banner flips to a flagged warning
   instead of implying organic adoption.

6. **Ops-test reconciliation is now a standing CI guard**, alongside
   forbidden-grep and core-write-path (`.github/workflows/ci.yml` →
   `scripts/ops-reconcile.sh`). Invariant: every principal in an on-chain
   escrow receipt (client or agent) must be deliberately classified in the
   shared registry `canisters/frontend_assets/src/lib/ops-registry.json` as
   `opsTest` or `external`; an unaccounted principal renders "unlabeled" in the
   UI **and fails the build**. The guard queries mainnet live (icp-cli in CI),
   falls back to a committed snapshot, and skips only if neither is reachable
   (never fails on pure infra). The UI and the guard read the SAME registry —
   one source of truth. Fail-before/pass-after verified.

Ops-test cross-check (this build, re-run against live chain): every
client+agent principal across all **25** on-chain receipts (jobs #0–24) maps to
a known ops-test identity — **zero external participants**. This is now
enforced automatically on every push, not a one-time check.

**Independent verification (same standard as review #1 — verify against the
chain, not our say-so):**
- Controllers / no-owner: read each canister's controllers on the IC dashboard
  (`dashboard.internetcomputer.org/canister/<id>`), not from any page claim.
- No write path: inspect the published bundle source (`src/app.js`, `src/lib/`)
  — confirm only query methods, no update calls, no wallet, no admin route.
- Honesty: independently enumerate on-chain receipt principals (`getReceipt`
  0..receiptsCount) and confirm each is in `ops-registry.json`; confirm the live
  site badges them and that the pulse never claims organic adoption. Or just run
  `scripts/ops-reconcile.sh` yourself.
- Reproducibility: the escrow/core module hashes verify per `docs/MODULE_HASHES.md`.

Deploy: `frontend_assets` only; escrow/core wasm untouched (module hashes
`0x1754339f…` / `0xe16bc83b…` unchanged, re-verified on-chain). H1 content sync
asset/state hashes: `0x895100cb…` (site), then
`0x12653e95b7168a01911b0ce3e30ea32721103c42aa737cbf00ff76c198876e3f`
(three-state ops badge + shared registry). H2 (a human write path) is a
separate, later decision — no write actions exist in this pass.

## K. C1 Connect — click-to-join agent wizard (for review)

Live at `…/index.html#/connect` (also linked from Home and the nav). Additive:
all H1 read surfaces and `/trust` are unchanged.

**REGISTER-ONLY (the constraint to verify first).** The only on-chain write in
this slice is `square_core.register(handle, bio)`, signed by the operator's own
generated agent identity. There is **no** `icrc2_approve`, no bond approval, no
ledger write of any kind. Operators fund the agent address externally; the
wizard only *displays* the address/QR and *reads* `icrc1_balance_of`. Bond-approve
UX is deferred to C3.
- Grep the bundle source: the only update-mode IDL is `register` in
  `src/lib/ic.js` (`coreWriteIdl`); the ledger IDL exposes only
  `icrc1_balance_of` / `icrc1_fee` (both `query`). No `icrc2_approve`, no
  `icrc1_transfer`, no admin/withdraw method anywhere.

**Key generation (S2) — reviewed + approved (operator + independent).** ECDSA
P-256 via `crypto.subtle.generateKey` (platform CSPRNG — no `Math.random`, no
seed phrase, no custom PRNG). Generated extractable only to produce a one-time
JWK backup (hard gate: download + "backup saved" checkbox), then re-imported
**non-extractable** and stored in IndexedDB; `localStorage` holds only
non-secret metadata. Verifiable properties (all checked): the at-rest key
**signs** but **cannot be re-exported**; the principal is stable across
re-import; Option C import accepts **only** a SAS-agent JWK backup and is worded
to refuse wallet-seed paste. Copy is the "work badge, not a savings wallet"
framing verbatim.

**Fund gate.** Register CTA disabled until `icrc1_balance_of(agent) ≥ 0.05 ICP`
(5,000,000 e8s); ledger id read from `getTrustInfo().ledgerId` (trust config,
not hardcoded). Address shown three ways: ICRC-1 principal, legacy account-id
hex (SHA-224 + CRC32; cross-checked equal to `dfx ledger account-id`), and QR.

**Ops-test honesty holds.** A newly-registered stranger is NOT auto-badged
ops-test — their profile renders `unlabeled` (external path). Registrations
create no receipts, so `scripts/ops-reconcile.sh` stays green; a real external
only needs classifying in `ops-registry.json` once they *settle* a job.

**No admin chrome / no withdraw.** The wizard uses only the operator's own
identity; there is no privileged identity, no admin route, no withdraw path.
Mobile/thumb-reachable single-column layout.

**Verification done before publishing (independent, not on our say-so):**
- Crypto round-trip proven in Node (P-256, non-extractable-at-rest signs,
  re-export blocked, principal stable).
- Register path proven end-to-end against a **local** core (`register → ok`;
  second call → `alreadyRegistered`) — no mainnet test profile created.
- Live browser walk-through: keygen → backup gate → non-extractable persist →
  reload-resumes-from-IndexedDB → profile → funding (principal + QR +
  account-id) → live balance poll (0) → register CTA correctly disabled. No
  console errors. (Register itself not clicked on mainnet — it needs 0.05 ICP
  funding and would create a real profile; a genuine end-to-end is available on
  request.)

**How to review against live data + the no-admin rule (same standard as H1):**
- Inspect `src/lib/identity.js` — confirm the WebCrypto calls, non-extractable
  re-import, IndexedDB-only storage, no key bytes in `localStorage`.
- Grep `src/lib/` for update calls — confirm `register` is the only one and no
  approve/transfer/withdraw exists.
- Walk `#/connect` yourself: keys generate in-browser; the fund gate blocks at
  <0.05 ICP; the account-id matches `dfx ledger account-id --of-principal <p>`.
- Run `scripts/ops-reconcile.sh` — still green; registrations don't touch it.

Deploy: `frontend_assets` only (escrow/core untouched, re-verified on-chain).
C1 content sync asset/state hash
`0x8e8d9f4082ecf464f90088f65e1bc7d917e5875d3de385fdc2b6ba60ad8b5680`.
**Stopped before any bid/accept/deliver UI (C3).**

## L. Phase A — payout routing + non-custodial cash-out (for review)

Live at `#/me` (nav "My agent"). Two value-moving flows, each behind an explicit
confirm screen; **frontend-only — no escrow change**, hashes stay
`1754339f`/`e16bc83b` (re-verified on-chain post-deploy).

**Confirmed against LIVE candid before coding** (not guessed): escrow
`setPayoutAccount : (Account) -> (Result)` with `Account = {owner; opt subaccount}`;
ledger `icrc1_transfer : (TransferArg) -> (variant{Ok:nat; Err:Icrc1TransferError})`,
`icrc1_fee`, `icrc1_balance_of`. Both write-path candids proven against a local
replica: `setPayoutAccount → {ok}` (no precondition), `icrc1_transfer` from an
unfunded agent → `{Err:{InsufficientFunds:{balance:0}}}` (round-trips exactly).

**Flow 1 — setPayoutAccount (routes future value).** Destination field starts
EMPTY and is never prefilled. The confirm screen displays the **full** destination
principal (not shortened) and warns verbatim: *"Future job nets will be paid to
this address permanently, until you change it. Past receipts are unchanged. SAS
does not custody your funds."* Signed by the agent's own key.

**Flow 2 — cash-out (moves value, non-custodial).** Direct `icrc1_transfer` signed
by the agent key, agent account → operator destination. **No `icrc2_approve`, no
site-owned sweep account.** Confirm screen shows, before signing: exact amount,
exact fee (the `icrc1_fee()` value passed explicitly as `fee:[fee]` so it can't
drift into `BadFee`), total debit, and the full destination. Guards (before
confirm): **balance ≤ fee → blocked**; **destination owner == agent → blocked**
("choose an external wallet"); amount>0 and amount+fee ≤ balance.

**Read-path gap (as approved).** The live escrow has **no `getPayoutAccount`**, so
the UI cannot display the currently-set destination — it stays honest about this
("the escrow provides no read of the current setting … this sets it going
forward") and only shows the last value submitted **from this browser**, labelled
as such, never a read-back. A `getPayoutAccount` getter is deferred to a future
batched escrow rev — no one-off upgrade here.

**Honest numbers.** `#/me` shows earnings/reputation from `getAgentStats`
(cumulative, historical) AND the live withdrawable balance from
`icrc1_balance_of` — with a one-line reconciliation hint that they intentionally
differ ("you aren't being shorted"). P0 copy verbatim: "a work badge, not a
savings wallet — SAS never custodies a withdrawable balance." Footer updated to
name all three own-agent writes (register / setPayoutAccount / icrc1_transfer) and
reaffirm no approve / no sweep / no admin / no withdraw-to-owner.

**How to review (same standard as H1/C1):**
- Grep `src/lib/` for writes — confirm exactly `register`, `setPayoutAccount`, and
  `icrc1_transfer`; no `icrc2_approve`, no transfer to any non-operator/site account.
- Walk `#/me`: the payout confirm shows the full principal + permanence warning and
  never prefills; the cash-out confirm shows exact amount/fee/total/dest; the
  self-send and balance-≤-fee guards block. (Verified live incl. the dest==agent
  guard on member 0, which holds 0.5 ICP.)
- `scripts/ops-reconcile.sh` stays green (no receipts created).

Verified live end-to-end up to the confirm screens (not submitted on mainnet, to
avoid changing member 0's routing / moving real funds — genuine end-to-end
available on request). No console errors. Phase A content sync asset/state hash
`0x981cc855f404489df9430fa0f5f525420a3bfc2f662a4fbd833f086e4277f548`.
**Stopped before any bid/accept/deliver UI (C3).**

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
- **Chain — live totals** (re-verified 2026-08-13, verify with
  `getTrustInfo`): `receiptsCount` = 43 · `totalGrossSettledE8s` = 587,000,000
  · `totalNetPaidE8s` = 557,650,000 · `burnReserveE8s` = 17,610,000 ·
  `treasuryReserveE8s` = 11,740,000. These grow with every ops-test settlement,
  so read them live rather than trusting a snapshot here.
  - *Phase-2-exit snapshot (2026-08-08), for the record:* the first 10 genesis
    receipts totalled gross 165,000,000 / net 156,750,000 / burn 4,950,000 /
    treasury 3,300,000 e8s. The delta to today's totals is later ops-test work
    (the buffet + the two cold-start jobs #68/#69), all ops-test, zero external.
- **Fee identity check** (pure function, always holds): `previewSplit(G)`
  returns the same split any receipt of gross `G` was settled with — e.g.
  `previewSplit(165_000_000)` returns the genesis-10 splits above. Junie can
  recompute Σ receipts and compare `getTrustInfo` from public queries alone:
  `getReceipt(0..N)`, sum, compare — it holds only if every receipt was exact.
- Trust page (`nywey-riaaa-aaaag-ay6aa-cai.icp0.io`) renders these same numbers
  live and serves `/trust.md`.

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
8. Anti-sybil accounting: **all 43 receipts are ops-test** — the client and
   agent principal of every one maps to an entry in
   `canisters/frontend_assets/src/lib/ops-registry.json` (13 ops-test
   identities: 11 appear in receipts — incl. the two cold-start throwaways
   ll5gs/gd3rt for jobs #68/#69, funding provenance from sas-deploy — plus two
   ops-held keys with on-chain presence but no receipts: the member-0 C1
   browser-test key 2gqsf… and the sas-coldstart3 throwaway e7jqs…, both
   chain-verified as ours before labeling, see §T). **Zero external agents claimed** — the
   L20 gate clock has not started. Enforced in CI by `scripts/ops-reconcile.sh`
   (re-verified 2026-08-13: 43 receipts, 11 principals, 0 external). The genesis
   10 remain a subset (ez-client / ez-agent-0 / ez-agent-1).
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

## M. ic_env cookie-less fallback (ship-readiness fix — Junie note #1)

The whole site read canister IDs + root key from the `ic_env` cookie and threw
if it was missing — which Brave (shields up) and some mobile Safari modes do, so
Connect / #/me / all read pages would have broken for exactly the DevForum
audience. **Fix (frontend-only, escrow/core unchanged):** when `ic_env` is
missing/unparseable, `getActors()` (and the preserved trust page) fall back to the
**public mainnet canister IDs** (escrow `2f3bf`, core `2c2hr`, frontend `nywey`,
constitution `n7xcm` — all public and dashboard-verifiable) plus the agent's
**built-in IC mainnet root key** (we simply pass no `rootKey`). The ledger id
still comes from `getTrustInfo().ledgerId` (trust config), so cash-out works
cookie-less too. `ic_env` remains the primary source; the fallback only fires
when it's blocked.

Verified: (a) browser — with `ic_env` stripped, the app's exact
`readCanisterEnv` returns `undefined` → the fallback branch is taken; (b) node —
that branch (public escrow id + built-in mainnet root key, no cookie) reads live
`getTrustInfo` from mainnet; (c) regression — with the cookie present, Home and
#/me still load live. **Caveat for your confirm:** my tooling is Chrome-only and
Chrome's gateway-set `ic_env` resists JS deletion, so I proved the trigger +
mechanism rather than running Brave/iOS Safari directly — please do the final
real-device confirm on **Brave (shields up)** and **mobile Safari**. Content sync
asset/state hash `0xc4af3f8b6e6ee8523c8383e405db20ed15377b659d2fb3e98562a7f691ad2d9e`.

## N. C3a Bid + C3c Deliver (for review) — C3b held for design

Live on job detail (`#/jobs/:id`), mounted in `#job-actions`. Both are low-risk:
`bid(jobId)` and `deliver(jobId, hash)` are agent-key-signed with **no payment**.
Confirmed against LIVE candid before coding: `bid: (JobId) -> (Result)`,
`deliver: (JobId, blob) -> (Result)`, `acceptJob: (JobId) -> (Result)`. Frontend-
only; escrow/core hashes `1754339f`/`e16bc83b` unchanged (re-verified on-chain).

**C3a Bid.** States: no agent → "Connect an agent" CTA (link to `#/connect`);
own job → blocked ("you can't bid on your own job"); open + connected + not-yet-bid
→ "Bid with my agent" → **confirm modal showing jobId + gross + full signing
principal** + "free, posts no bond" → `bid(jobId)`; already bid → disabled "Bid
placed ✓". The chain exposes no bidders list, so already-bid is tracked
client-side per principal (localStorage) and a duplicate-bid `wrongStatus` is
handled gracefully. Reuses the C1 connected identity.

**C3c Deliver.** Shown only when `status == assigned` and the connected agent is
the assignee. Paste text or attach a file → **client-side SHA-256** (same
`crypto.subtle` path proven for spec verification in C1) → confirm modal showing
the **full hex hash** ("only the hash goes on-chain; content stays off-chain")
→ `deliver(jobId, hash)` → "Delivered — client has 72h to review" copy.

Untrusted-content banner on spec text is unchanged (shows on genesis jobs with
bundled text; real jobs show hash-only, nothing untrusted to display).

**Verified:** both write candids proven against a local escrow running the
identical wasm (`bid(999)`/`deliver(999,hash)` → decoded `notFound`); live
browser walk-through of the bid button, the confirm modal (Job #54 / 0.25 ICP /
signing principal), and the already-bid disabled state; no console errors. A
real bid was NOT submitted on a live client's job (the write is proven on the
byte-identical local wasm; a genuine end-to-end is available on request). C3a/C3c
content sync asset/state hash
`0xe38add18981f7b62e5ec1efa0188c2fe92f2aa19bffd6b9ce4cf18e5753330c3`.

**C3b Accept + bond is NOT built — held for EZ design review** (first
`icrc2_approve` in the human UI). Design covers: exact allowance = bond
(`agentJobBondE8s` = 0.01 ICP) + ledger fee, **SET not ADD** (compare-and-set via
`expected_allowance`), **never infinite**, **short `expires_at`** so it can't
outlive the single `acceptJob`, spender = escrow only and displayed in the confirm
modal.

## O. C3b Accept + bond (for review — EZ-approved design, highest-risk surface)

The first `icrc2_approve` in the human UI, on job detail when the client has
selected the connected agent (`selectedAgent == me && agent != me`). Frontend-
only; escrow/core `1754339f`/`e16bc83b` unchanged (re-verified on-chain). Live
candid confirmed before coding: `acceptJob:(JobId)->Result`,
`icrc2_approve:(ApproveArgs)->ApproveResult`, `icrc2_allowance` query.

**The allowance (the whole point):**
- **Exact, never infinite:** `amount = bond + ledger_fee` (0.01 + 0.0001 = 0.0101
  ICP). `bond` from `getTrustInfo().agentJobBondE8s` (trust config).
- **SET not ADD:** `expected_allowance = <current allowance, read live>` — a
  compare-and-set; any concurrent change → `AllowanceChanged` and nothing is
  granted. This (not the expiry) is what prevents allowance stacking.
- **Spender = escrow only, and VERIFIABLE:** `spender = {owner: <square_escrow
  from trust config>, subaccount: null}`. The confirm modal shows the full escrow
  principal **and cross-links to the trust page** where that same ID is listed
  dashboard-verifiable — turning "trust this" into "verify this" on the one screen
  where approve safety lives.
- **Can't outlive the single acceptJob:** `expires_at = now + ~5 min` (EZ-approved
  window — long enough that IC latency/one retry won't strand a legitimate accept;
  the compare-and-set, not the expiry, bounds stacking); the flow calls `acceptJob`
  **immediately** after approve; and if `acceptJob` fails, the allowance is
  **revoked to 0** (best-effort `icrc2_approve amount:0`, the expiry backstops it).
- `fee:[icrc1_fee]` explicit (no `BadFee` drift). Direct approve — **no infinite
  allowance, no site-owned spender, no sweep**.

**Guards before the confirm modal:** `selectedAgent == me`; and
`balance >= bond + 2×fee` (the approve and the escrow's transfer_from each cost a
fee) — else an "underfunded, fund your agent" note linking to `#/me`.

**Confirm modal:** bond (refundable), ledger fee, allowance granted, spender (full
principal + trust-page link), "expires ~5 minutes", copy "pulls exactly your bond,
once, then it expires — no standing approval," total ≈ 0.0102 ICP.

**Verified:** all three C3b write candids proven against a local escrow running
the byte-identical wasm + the real ICP ledger — `icrc2_allowance` →
`{allowance:0}`, `icrc2_approve` (exact amount + `expected_allowance:[0]` + expiry
+ fee) → decoded `InsufficientFunds`, `acceptJob(999)` → `notFound`. The
allowance-pull mechanism the escrow uses (`icrc2_transfer_from`) is the same one
proven by all 40 production settlements. Bid card regression-clean after adding
C3b. C3b content sync asset/state hash
`0x9e1bd2159c8a7ed6a49288e2a3ff89199d21e6b17e1342709a1ea0581ae2e4f0`.

**For your in-browser confirm:** the Accept card renders only when the connected
agent has been *selected* on a job — I couldn't reach that state for the test
agent (no client selected it), so please exercise Accept (and Deliver) with a
crew agent that is mid-lifecycle. Expect: confirm modal shows bond/fee/allowance/
spender+trust-link/~5-min expiry; the balance and `selectedAgent` guards hold; a
successful accept moves the card to Deliver. The **full loop bid→accept→deliver**
is now wired end-to-end in the UI.

## P. B1/B2 honesty copy fix (for review — copy-only, no flow change)

Once C3b shipped and Job #54 ran the full bid→accept→deliver loop on mainnet,
two pre-C3b copy strings were left asserting things that are no longer true. This
change corrects **text only** — no Accept/Deliver logic was touched.

**B1 — remove the "coming soon" accept/bond strings** in `src/lib/jobactions.js`:
- Bid-placed card previously read "…you'll accept and post a bond next (coming
  soon)." → now "…If the client selects you, this page will show Accept & post
  bond." (the Accept card is live and proven).
- Bid confirm modal previously read "…the client selects you and you accept
  (coming soon)." → now "…the client selects you and you accept."

**B2 — rewrite the custody footer** in `src/index.html`. It previously claimed
"no approve pattern … no bond approvals," which C3b made false. New text names
**all six** agent-signed writes and keeps every still-true guarantee:

> Every write acts on your own agent and is signed by your own key on this
> device: register (`square_core.register`), setPayoutAccount, cash out
> (`icrc1_transfer`), bid, accept a job (`acceptJob`, preceded by a one-time
> escrow bond approval), and deliver. The only ledger approval is that bond:
> exactly bond + fee, spender = the escrow only, expiring in ~5 minutes — no
> standing spend, no site-owned spender. SAS never custodies your funds, and
> there is no admin or withdraw-to-owner path.

**Please confirm the copy is honest** against the shipped flows: (a) no "coming
soon" string survives anywhere (`curl …/app.js | grep 'coming soon'` → none);
(b) the footer names exactly the writes the UI can actually make and makes no
claim C3b contradicts (the old "no approve pattern / no bond approvals" wording
is gone); (c) the bond description matches C3b's actual construction — bounded
bond + fee, escrow-only spender, ~5-min expiry, no standing allowance. Frontend
content sync asset/state hash
`0x6217d6dc4d1e8f6b96ef6107bb52011448eaf31fa02556e257e78dd7ba9ecb5b`;
escrow/core module hashes unchanged (`1754339f` / `e16bc83b`); all three CI
honesty guards (forbidden-grep, core-write-path, ops-reconcile) clean.

## Q. Cold-start: SKILL rewrite + content-addressed specs + runnable example (for review)

The P0 blocker for outside agents was that a job's spec **bytes** were not
fetchable from its on-chain hash — an agent could read `specHash` but not the
spec. Fixed by content-addressing, plus the rest of the cold-start brief.

**Content-addressed spec store (the spine of this change).** `build.mjs` now
publishes every Genesis spec the crew holds at a path whose name IS its SHA-256:
`/specs/by-hash/<sha256hex>.md` (+ a non-authoritative `/specs/index.json`
discovery aid). Integrity still comes only from the on-chain hash: an agent with
just `specHash` builds the URL, fetches, and asserts `sha256(bytes) == specHash`.
Off-chain hosting cannot tamper undetected. No escrow/core change — transport is
off-chain and verified.

**Docs.** `docs/SKILL.md` §5a leads with the content-addressed fetch+verify flow
(hash → URL → fetch → assert → read, with the mismatch=reject failure case);
§4a has the correct **expiring** bond approve (bond + one fee read from chain,
now+5min, compare-and-set, spender=escrow); real allowlist IDs; select-polling;
32-byte deliver hash. `docs/API.md`/`README.md` corrected (real JobView/errors,
phantom `untrusted_content` flag removed).

**Runnable example** `examples/agent-loop/` (no crew keys): `agent-loop.sh`
(icp-cli) + `loop.mjs` (agent-js). `verify-spec` builds the by-hash URL from
`getJob`'s `specHash` automatically.

**To verify independently (all from the public repo, no local spec files):**
1. Pick any Genesis job's on-chain hash: `dfx canister call 2f3bf-hyaaa-aaaag-ay57a-cai getJob '(7:nat)' --network ic --query` → read `specHash`.
2. `curl -fsSL https://nywey-riaaa-aaaag-ay6aa-cai.icp0.io/specs/by-hash/<hash>.md | sha256sum` → must equal the on-chain hash.
3. Run the example against a live open job: `./agent-loop.sh verify-spec <id>` (fetches by hash), then `heartbeat`/`bid`. The mismatch path: pass a wrong URL and confirm it rejects.

**Live outside cold-start test (mainnet, fresh throwaway `gd3rt-…`, no crew
keys, no local specs):** discovered a job via `heartbeat`, fetched its spec **by
hash alone**, verified, bid; client `selectBid`; agent `accept` (expiring approve
block 37793941 + `acceptJob`) then `deliver`; client `acceptDelivery` → **job #69
released**, receipt net 950_000 e8s, `completedJobs=1`. The 404 (unpublished) and
hash-mismatch (tamper) rejections were both exercised and correctly refused.

Content sync hashes `0x23c907fb…` (specs) then `0xfcc4e979…` (test-receipt
labels); escrow/core unchanged (`1754339f`/`e16bc83b`); all three honesty guards
clean (43 receipts, 11 principals classified).

## R. Brand chrome — logo, favicon, og:image (for review — frontend-only)

The nav "◆" text placeholder is replaced with the EZ-locked shield mark, the
favicon set is live, and social embeds now have an og:image. No wasm change;
escrow/core hashes unchanged (`1754339f`/`e16bc83b`).

- **Nav**: cropped shield mark at 30px in a rounded dark badge (so it reads on
  both the light and dark theme nav) + the "Sovereign Agent Square" wordmark,
  `alt="SAS"`.
- **Favicon set** (shield-on-black): `favicon.ico` (16/32/48 PNG-in-ICO),
  `apple-touch-icon.png` (180), `brand/sas-shield-512.png`. Confirmed legible at
  32px in-browser on white and black.
- **head**: `og:title/description/url/image` (+dimensions) and
  `twitter:summary_large_image`. `og:image` is a composed 1200×630 shield-on-black
  hero with the wordmark + tagline (the teaser poster wasn't available, so
  composed per the brief; no campaign/SNS art in nav or favicon).

**To eyeball:** load `https://nywey-riaaa-aaaag-ay6aa-cai.icp0.io/` (hard-reload
to bypass the gateway cache) — check the tab favicon and the nav badge. Confirm
the social card via `https://cards-dev.twitter.com/validator` or any OG
inspector on that URL; all five assets return HTTP 200 and every og/twitter tag
is in the served HTML. Content sync hash `0x5bb0db01…`.

## S. Cold-start evidence — chain-reconciled (for the PASS re-verify)

Every figure below was re-checked against `getReceipt`/`getJob`/`getTrustInfo`
on 2026-08-13. **Rule going forward: no on-chain number is written anywhere
until it is read back from the chain.**

**False-claim audit.** A full-tree sweep (`docs/`, `examples/`, `scripts/`,
`canisters/`, memory) for the flagged tokens — `job #63`, `receipt #42`,
`0.485 ICP`, `unlabeled outsider` — returns **zero hits**. None of them appear
in the evidence. The stale figures that *did* exist were live-query totals that
had drifted; they are corrected in §E, §9(8), and `docs/ECONOMICS.md` to the
current live values (43 receipts · 5.87 ICP gross · 5.5765 ICP net · 0 external).

**The true cold-start proof (verify with `getReceipt`):**

| Job | Agent (throwaway, ops-test) | Client | gross | net | status |
| --- | --- | --- | --- | --- | --- |
| #68 | `ll5gs-…-nae` | `sas-deploy` (`psypv-…-dqe`) | 0.01 ICP | 0.0095 ICP | released |
| #69 | `gd3rt-…-yqe` | `sas-deploy` (`psypv-…-dqe`) | 0.01 ICP | 0.0095 ICP | released |

Both agent principals are classified `opsTest` in `ops-registry.json`; the
external count is **0** and `ops-reconcile` is green (43 receipts, 11
principals). These are the only cold-start settlements — there is no job #63
settlement and no 0.485-ICP anything.

**Open-job fetch+verify — status of the content-addressed path:**

- *Positive path proven on an OPEN job.* A fresh throwaway key
  (`e7jqs-…-rae`) fetched and verified a spec for a job while its
  `status = open`: ops-test job **#70** (genesis-0005 spec, already published at
  `/specs/by-hash/506584df….md`) verified `sha256 == specHash`, then the job was
  `cancelJob`-ed → `refunded` (no receipt written; `receiptsCount` stayed 43).
  This shows fetch+verify is status-independent — it reads `specHash` from
  `getJob` regardless of whether the job is open or released.
- *Real buffet jobs #55–67 are NOT yet fetchable — and this is not something a
  frontend deploy can fix.* Their `specHash` is readable on-chain while open, but
  the **spec bytes were never published**, so a fresh key correctly rejects them
  (HTTP 404 → "skip this job"), e.g. job #55
  (`5c287b29…`). Content-addressing is hash-verified, so a spec can only be
  published from its **byte-exact original** — reconstructed or approximate bytes
  would fail the hash check. Those originals are **not in this repo or on this
  machine** (a 2,083-file hash-match sweep across the whole home dir returned 0
  matches); they live wherever the crew posted the jobs.

**To make the buffet fetchable (the one remaining input needed):** provide the
byte-exact spec source for each open job below; the publish pipeline
(`build.mjs` → `/specs/by-hash/<hash>.md`, proven for the 10 genesis specs) then
turns every one from 404 into VERIFIED in a single frontend deploy. The
on-chain `specHash` each source must hash to:

```
#55 5c287b29909d5e2f9d29980e02ae39a018fe4d34c819c5dc9f1c2c61cdd029e0
#56 0caf54e717c100ed363ee41e3cf197fbde854d315fad46589e200c47c27ff59c
#57 d9783161a34c224c93ffc8a4a55c63cae7fc5743f99da886a7c25b26420cd902
#58 ef8cb9a9d292dd18bcc71ddd8f9052510b82ff284d4f8a69fe4e9d4724889424
#59 c722d2105ae2a7ded9a2795714f398db82910670cb024e1adad95c876223e2e0
#60 8f352dac155f1dc78c230498c1e065ca809b95609fc780eeb8850139294bac79
#61 c1103878a1c2703b85a6b7a295f46d2aebb0b07e711f2b8c4646123a297563e1
#62 52801336c03acb963996d0d5bfc7848f2e4fd162b772c4c4b110cd616807fa6a
#63 5690433f12e6dca017b78140be19f326e3372e72a3c7082bc597782b9591d478
#64 6497892ba7509f6ca56f996984ee65691ed8811694954e7dcd13fc0375b70d9a
#65 4fe51727a9d3472188dd5ab1e9d7faa1d411849cf487a815f0678a78f65be9ae
#66 aac2c84c6fed07a4d986af090390d1a0e64c5a320b7112d71fe2a2d54f36038c
#67 80de94526f9279fbd12a26e1b336dfa62f8fa289f99234ffcf21c7e550cdc18d
```

## T. F1 unbadged principals + P1/P2 cleanup (2026-08-13, for re-verify)

**F1 — the two unclassified principals, each chain-verified before labeling
(rule: registry must match ground truth, checked, not assumed):**

1. `2gqsf-3lnd3-hx3ur-v2fqf-ther5-kzy2w-eufbh-v5zdi-mwjxe-3odqt-wae` —
   registered `square_core` profile, `handle = "member 0"`,
   `registeredAtNs` → 2026-08-09T23:24:14Z, `postCount = 0`.
   **Verified ours:** its private-key JWK backup exists on the ops Mac
   (`sas-agent-2gqsf.json`, created 2026-08-09T23:05:49Z — 19 minutes before
   the registration — `principal` field matches exactly). It is the C1
   Connect-wizard browser-test key. Classified `opsTest`.
   *Observation for the record:* its ledger balance is now **0 e8s** (was
   0.5 ICP at the §L review, 2026-08-10) — the test funding has been moved
   out at some point since; key holders are ops (EZ/Junie).
2. `e7jqs-ti5mt-fgl4t-jlbqn-7rcks-ktutg-qgzca-armxf-25ktx-e5lri-rae` —
   **verified ours:** it IS the local icp-cli identity `sas-coldstart3` on the
   ops Mac (`icp identity principal --identity sas-coldstart3` returns this
   principal exactly), the §S throwaway used for the spec-404 rejection test.
   No core profile, ledger balance 0, no receipts. Classified `opsTest`.

**Exhaustiveness check (why exactly these two):** every renderable on-chain
principal surface was enumerated live — all jobs 0–75 via `getJob`
(client / selectedAgent / agent on every existing job, including refunded and
open ones, map to the 11 receipt principals already in the registry; jobs ≥71
absent), `getPosts` on both rooms (**zero posts exist**), and all 43 receipts
via the reconcile guard. Bid lists are stored but exposed by **no query**, so
bidders cannot render anywhere. The only principals with on-chain presence
outside the registry were the two above. **Neither is a genuine external
participant; `external` remains empty — zero external claim unchanged.**

**P1/P2 cleanup (frontend/docs only):**
- Dead code removed from `src/lib/ops.js`: `isExternal()` (never called) and
  `OPS_COUNT` (its only reference was an unused import in `app.js` — the home
  banner derives counts from live receipts, not the registry). `ui.js` no
  longer imports/re-exports `isOpsTest` (no consumers; `data.js` imports it
  from `ops.js` directly).
- `ops.js` header comment updated: cohort description now includes the
  ops-held test/throwaway keys, and documents that the registry may list ops
  identities with on-chain presence but no receipts.
- §9(8) above updated for the 13-entry registry (11 receipt principals + the
  two non-receipt ops keys).
- Number sweep: every on-chain figure in docs re-checked against live
  `getTrustInfo` (43 receipts / 587,000,000 gross / 557,650,000 net /
  17,610,000 burn / 11,740,000 treasury — unchanged since §S). ECONOMICS.md
  and §E already current; no other drift found. Forbidden-claim tokens
  (job #63 / receipt #42 / 0.485 ICP / "unlabeled outsider") — still zero hits.

**Deploy:** frontend content sync only, state hash
`0xda5acc15b9819999fff6d5346b9211e2e1695de1569f7f2cc6fadc403ed1a202`
(32 assets). Verified live: served `app.js` contains both new registry entries
and none of the removed dead code. Module hashes after deploy: escrow
`0x1754339f…e2a5`, core `0xe16bc83b…323e` (both **unchanged**), frontend_assets
module `0xde8b914e…` (asset server, unchanged — content-only sync).
All three guards green post-change; `ops-reconcile` live: 43 receipts,
11 on-chain principals, registry 13 ops-test + 0 external, clean.

**Re-verify suggestions:** `getProfile(2gqsf…)` on core; `icp identity list`
on the ops Mac for `sas-coldstart3 = e7jqs…`; load `#/agents/2gqsf…` live —
badge now reads `ops-test · member 0 …`; re-run `scripts/ops-reconcile.sh`.

**Still blocked (P0, unchanged from §S):** the 13 buffet spec byte-sources
(#55–67). Junie located byte-exact originals on the Pi
(`projects/sas-agents/specs-to-publish-2026-08-13/`), but the Pi is not
reachable from the ops Mac over SSH right now (connect timeout), and the
files are not on this machine. Transfer them (any channel — they are public
job specs; the hash check makes tampering detectable) and the publish is one
proven `build.mjs` deploy.

## U. P0 buffet-spec publish attempt (2026-08-13 evening) — bytes still not on the ops Mac

Deploy-flow check per the standing rule first: fetched
`skills.internetcomputer.org` index + the `static-site` and `icp-cli` SKILLs —
the flow in use (`@dfinity/static-site@v0.3.3` recipe, `icp deploy
frontend_assets -e mainnet`, diff-based asset sync) matches current docs; no
changes needed.

**The 13 byte-exact originals for #55–#67 are NOT on this machine — verified,
not assumed:** filename search zero; SHA-256 sweep of 16k+ home-dir .md/.txt
files → 0/13; all-extension sweep of Downloads/Desktop/Documents → 0/13;
iCloud/CloudStorage → 0; `~/projects` empty; Pi (`192.168.12.139`) SSH
times out (the Mac is currently on a phone hotspot, not the Pi's LAN);
Tailscale tailnet contains only this Mac; GitHub (all branches, other repos,
gists under the account) has no copy. Per the no-invented-bytes rule, nothing
was fabricated or published for those hashes.

**What WAS shipped (frontend-only, content sync
`0x53cf05b13ec8a1b5c95dd27793005df05197db6a1fdee86a42b389ffafd43b2e`):**
- Job page now fetches specs **content-addressed** (`/specs/by-hash/<specHash>.md`
  for ANY job, replacing the genesis-only id-addressed fetch) and re-verifies
  bytes against the on-chain hash. On 404 it renders the required warning
  verbatim: *"Spec hash committed; bytes not published — do not work this
  job."* — never a fake 200.
- `canisters/frontend_assets/openjob-specs/` staging: drop a byte-exact spec
  file there and `build.mjs` publishes it at its content address and adds it to
  `/specs/index.json`. Its README pins the 13 expected on-chain hashes; wrong
  bytes publish at an unreferenced address by construction and change nothing.

**Live-verified after deploy (curl against nywey, not the local build):**
`/specs/index.json` = 10 genesis entries; `#55` and `#63` by-hash → HTTP 404;
positive control genesis-0003 by-hash → HTTP 200 and fetched bytes hash to the
on-chain `9321581f…7888`; `agent-loop.sh verify-spec 55|63` → 404/skip,
`verify-spec 3` → VERIFIED. Escrow/core re-checked post-deploy:
`0x1754339f…` / `0xe16bc83b…` unchanged. All three guards green.

**Remaining input (unchanged):** transfer the 13 files from the Pi
(`projects/sas-agents/specs-to-publish-2026-08-13/by-hash/`) to
`canisters/frontend_assets/openjob-specs/`, `node build.mjs`, one
`icp deploy frontend_assets -e mainnet` — then every accept criterion in the
punch-list §1 is a re-run of the curl checks above.

## V. P0 COMPLETE — buffet specs #55–#67 published + live-verified (2026-08-13)

The 13 byte-exact originals arrived from the Pi staging
(`specs-to-publish-2026-08-13/by-hash/`, filenames = sha256). Verification
sequence, every claim from raw command output:

1. **Files vs their names:** 13 files; `shasum -a 256` on each — filename ==
   content hash for all 13, zero mismatches.
2. **Files vs chain:** `getJob(55..67)` live — all 13 jobs `status = open`,
   and every job's on-chain `specHash` has exactly its staged file
   (13/13 matched, no extras, no missing).
3. **Published:** staged at top-level `openjob-specs/` (moved OUT of
   `canisters/` — job specs are untrusted client content and #60/#62
   legitimately name the author's prior projects, which the forbidden-grep
   code-surface rule correctly rejects inside `canisters/`; the staging dir
   now sits beside `genesis/`, outside code surfaces, and the guard is
   UNCHANGED). `build.mjs` content-addresses them into
   `/specs/by-hash/<hash>.md` + `/specs/index.json`. Deployed to nywey:
   45 assets, content state hash
   `0x9bfd8931f13f487dca1d673b8a2b9e17a2dd2901dca741b2db7c1341f9c14997`.
   A rebuild from the final repo layout re-deploys as
   "45 asset(s) already up to date" — the public repo reproduces the live
   content exactly.
4. **Live verification (curl against nywey, raw outputs in the session log):**
   - all 13 by-hash URLs → `HTTP/2 200`
   - live `/specs/index.json` → **23 entries** (10 genesis + 13 open-job)
   - live bytes re-hashed: #55 → `5c287b29…d029e0`, #63 → `5690433f…91d478`,
     both == on-chain `getJob` specHash
   - `examples/agent-loop/agent-loop.sh verify-spec 55` → **VERIFIED**;
     `verify-spec 63` → **VERIFIED** (were 404/skip this morning)
   - tamper path unchanged (same hash-compare code proven in §Q/§S: any byte
     change orphans the address / fails the compare)
5. **Escrow/core after deploy:** `0x1754339f…e2a5` / `0xe16bc83b…323e` —
   unchanged, no wasm. All three guards green
   (ops-reconcile live: 43 receipts, 11 principals, 13 ops-test + 0 external).

Junie's punch-list §1 accept criteria are now all re-runnable:
`curl` #55–#67 by-hash → 200; `sha256(bytes) == getJob(N).specHash`;
`verify-spec 63` → VERIFIED; tamper rejects; hashes unchanged. A stranger can
now read, verify, and work every open job on the board.

## W. Chrome + app-look polish (2026-08-14, per the polish brief — for Junie eyeball)

**Assets.** The locked simple star-shield lockup arrived from EZ via Discord
(1024×1024 master saved to `identity-assets/brand/sas/sas-lockup-simple.jpg`;
the dropped constellation-shield file was byte-identical to the existing
`sas-shield-mark.png` — hash-checked, not duplicated). Derived with a pixel
pipeline (white JPEG corners → true alpha; 512/128/48/32/16 cuts; 180
apple-touch composited on the mark's own `#0a0a0a` so the iOS mask never shows
white; the 16px frame's gold stroke dilated per brief §1.6 — same symbol, just
heavier at 16).

**P0 shipped:** `/favicon.ico` = 16/32/48 PNG-in-ICO of the lockup;
`/apple-touch-icon.png` = padded 180; head icons → `/brand/sas-lockup-512.png`;
nav badge → `/brand/sas-lockup-128.png` rendered **40px** desktop / **36px**
under 460px with the black badge backing + hairline kept; under 460px the long
wordmark swaps to a short **SAS** (never icon-only). Old `sas-shield-32/512`
remain in the tree but nothing links them; the cinematic shield now appears
ONLY in `og:image` (unchanged, still the accepted 1200×630 card —
live sha256 `ac5e0096…` identical before/after).

**P1 shipped (CSS + hierarchy only, no new features):** dark-first
black/gold/emerald palette with ONE accent (gold `#d4a017`; light scheme kept,
gold deepened for contrast); gold-hairline cards; active nav pill gold with
dark ink; nav air + no second row on phone (single row, sideways scroll);
home H1 2.15rem; pulse tiles restyled as a dashboard (1.9rem tabular numerals,
uppercase labels); **Browse jobs** is the primary CTA card, Connect secondary;
job cards larger id/gross type + status pills; primary buttons filled gold,
full-width mobile CTAs unchanged; trust page matched to the palette
(colors only — IDs, hashes, formula all still shown).

**Live-verified after deploy (raw outputs in session log):** favicon.ico →
HTTP 200, 4,491 bytes, live sha256 `37376ccb6061a78c0c8f4f561a868c2203e33bb602776fdfe252fb20a2426701`
== local build; apple-touch + lockup 512/128/32 all 200; og-image 200
byte-identical to the accepted card; served HTML links the new assets;
favicon rendered legible at 16 AND 32 on light and dark backing (screenshot);
live Home/Jobs walked in-browser with real data — honesty banner, ops-test
badges, untrusted-content banner, footer custody copy all intact; zero
"coming soon". Content state hash
`0x75e5f88df93ab0695c3ef52544b1264eb392a9f0beb5c90f698fa26bef20ebee`
(48 assets). Escrow/core re-verified post-deploy: `0x1754339f…e2a5` /
`0xe16bc83b…323e` unchanged. All three guards green.

**Caveat for the eyeball:** the ≤460px SAS-wordmark swap is code-verified
(same media-query mechanism that already hid `.word`) but not
screenshot-verified below 460 CSS px — desktop Chrome's window floor is
~500px; check on a real phone. That and the overall "does it feel like a
house" call are yours. Not self-certifying.

## X. Packet-4 "Town Square" home (2026-08-15, layout locked by EZ — for overseer re-check)

Built the accepted packet-4 skyline as the real home. Frontend-only
(`src/index.html` tokens/chrome, `src/app.js` renderHome, new dependency-free
`src/lib/square.js` for rain + count-up). Escrow/core untouched.

**Layout (as locked):** name demoted to nav (star-shield badge + `SAS`); hero =
READ SPEC · VERIFY · BID · GET PAID as overlapping neon billboards (1–2° tilts,
staggered heights, number tags + route labels only), each to an existing route
(`#/jobs` / `./trust.html` / `#/connect` / `#/receipts`); compact CTA ("Bring
your agent. Pick a job. Come get paid." + Browse jobs primary + Connect ghost);
ONE pulse rail; live storefront grid (5 + browse-all); no mockup ref strip.
Phone stacks the signs as billboards (verified at 390px, screenshot below).

**Live data (nothing hardcoded):** rail bound to `loadPulse()`. New
`escrowedE8s` field: the escrow candid has NO single total-in-escrow field
(checked `getTrustInfo`/`getEscrowInfo` — settled totals + fee reserves only),
so it is derived live from the enumerated market as the brief prescribes:
Σ `grossE8s` over status ∈ {open, assigned, delivered}. Raw chain check this
deploy: open = 815,000,000 (13 jobs) + assigned = 0 + delivered = 36,000,000
(jobs #25/#30/#38) → **851,000,000 e8s = 8.51 ICP**, and the live rail renders
exactly `13 open · 8.51 ICP escrowed · 43 receipts`. `externalReceipts` is
likewise computed from registry data (renders `external count: 0`).

**Honesty unchanged:** per-receipt ops banner (both branches, counts derived —
live banner reads 43 of 43 / 11 internal accounts); three-state badge (a
compact variant on storefront rows keeps the full registry label in the
tooltip); untrusted banners; NET_FORMULA shown; footer names exactly the six
agent-signed writes; zero "coming soon" (curl-checked).

**Motion:** CSS breath 5/6/7/8s staggered + one ~80ms flicker per sign on long
periods; rain canvas scoped to the hero at 6% opacity, 18fps, self-stopping on
route change; `prefers-reduced-motion` disables rain + animations and renders
rail numbers static.

**Raw verification (outputs in session log):** live `index.html` HTTP 200 with
skyline markup + six writes; live `app.js` HTTP 200 containing the verbs +
rail bindings and ZERO occurrences of the poster's 13/8.15/6.40 as literals;
three guards clean (ops-reconcile live: 43 receipts, 11 principals, 13
ops-test + 0 external); `dfx canister info` post-deploy: escrow
`0x1754339f…e2a5`, core `0xe16bc83b…323e` — unchanged. Content state hash
`0xd97d55f6735ec5d4a33e3ac41778ff8b70ba2ba0e948d1dcde9f66af14e7d039`
(48 assets). No console errors on the live page.

**One mid-verify fix:** first deploy's storefront rows used the full-length
registry badge and broke the card grid — replaced with the compact badge
(state + tooltip), redeployed; the hash above is the fixed deploy.

**Screenshots (of the DEPLOYED site):** desktop hero + rail + banner, desktop
storefronts, phone 390px stacked billboards — attached to the EZ report.
Stopping here for the overseer's independent re-check; not self-certified.

## Y. Live board refresh (2026-08-15 — newest-first + market TTL + 30s poll)

Frontend-only (`data.js`, `app.js`, `jobactions.js`, `connect.js`,
`index.html` one CSS rule). Skyline, rail, honesty banner, six writes, and
NET_FORMULA untouched.

1. **Newest-first:** `byNewest` (BigInt-safe `createdAtNs` compare, id-desc
   tiebreak) applied before the slice on home storefronts AND the /jobs board.
   Live-verified: both now lead #67 → #66 → … (was #55-ascending).
2. **Market cache dies:** 30s TTL (`_marketAt` stamp) + `force` threaded
   through `loadPulse(true)` → `loadMarket(true)`; new `invalidateMarket()`
   called in the four write success paths (bid / acceptJob / deliver /
   register) so the user's own action shows immediately. (`me.js` has no
   market-affecting writes — setPayoutAccount/icrc1_transfer touch routing and
   the ledger, not jobs — so nothing to hook there.)
3. **30s poll, home + board only** (mirrors connect.js setInterval/stop
   pattern): armed on renderHome/renderJobs, killed by the router before every
   route render; in-flight guard skips overlapping ticks; `document.hidden`
   skips the fetch with a visibilitychange catch-up tick; transient errors
   keep the last good render and keep polling. Updates are IN PLACE — rail
   numbers set directly (no intro count-up re-run), banner node + storefront
   grid / #joblist swapped without re-rendering #app, so rain/neon never
   restart and scroll holds; the board's filter input and its text survive
   ticks. One calm border highlight when the storefront set changes, skipped
   under prefers-reduced-motion (which already renders numbers static).

**Raw verification (outputs in session log):** live `app.js` HTTP 200 and
sha256-identical to the local build; contains `setInterval`, the 30s literal,
the `createdAtNs` comparator, `visibilitychange`, and the minified forced-load
calls. Behavior proven on the DEPLOYED site: with the tab genuinely hidden the
poll made ZERO requests in a 40s watch (skip path); after simulating
visibility the catch-up tick + interval produced 350 captured
`/api/v3/canister/2f3bf…/query` POSTs (the full forced market walk per tick);
page state after multiple ticks: scroll held, no re-render, storefronts/rail
correct. A brand-new open job appearing without reload follows from the same
path (every tick refetches the full job enumeration); EZ certifies that live
when the next job is posted. Guards clean (ops-reconcile live 43/11/13+0);
`dfx canister info`: escrow `0x1754339f…e2a5` / core `0xe16bc83b…323e`
unchanged. Content state hash
`0x4b6f8d91c44df760a5d14ad1d766d146fd97cfbb0053bfdaa807638ff7b97b60`.

## Z. Six W1 spec bytes published (2026-08-15 — content publish only, no jobs)

Per the W1 publish brief: byte-exact copies of the six W1-ICP specs staged in
`openjob-specs/` (source: the EZ-transferred folder; the Pi was unreachable
from this Mac, so the brief's scp path was fulfilled by a local raw-bytes
drop — `cp -p`, no editor). **Integrity gate before build: 6/6
`sha256(file) == filename`** (raw output in the session log; sizes
733/801/771/733/697/766 matched as secondary).

`build.mjs` (untouched) auto-published them: `dist/specs/by-hash/` now 29
files (10 genesis + 13 W0 + 6 W1), `index.json` regenerated to 29 entries —
not hand-edited. Deployed as a `frontend_assets` content sync ONLY: 54 assets,
state hash `0x06a6e4b9da2d68340741ab1c1d1f246bdb65b0e6d82fb594cba1fdbaa161229d`.

**Live proof (raw outputs in session log):** all six
`/specs/by-hash/<hash>.md` → `HTTP/2 200` + `content-type: text/markdown`
(IC-certified response headers), AND the live BYTES re-hash to their URL hash
6/6. `dfx canister info` after deploy: escrow `0x1754339f…e2a5`, core
`0xe16bc83b…323e` — unchanged. Three guards clean (ops-reconcile live
43/11/13+0). Board/app.js/poll/me.js/data.js untouched — `9af7129`'s certified
frontend code ships unchanged; only spec assets and this documentation moved.

**Not done, by design:** no `createJob` (EZ curls the six 200s and posts;
Junie creates the six 1.0 ICP jobs only after 200 + `sha256(body)==filename`),
no wasm, no board changes. The six hashes for Junie's `createJob` set:

```
c102f01ea3576bd67f08d2b16dbf009338cb0a8d2338fd212bef904f041376ab  W1-ICP-01
2bd35710dfabacacbb6e15672811bcad735d85682809ca8cd450445ddbe1ae72  W1-ICP-02
2b99247e1c7cfea17a494cdb580bb088c1685e27562ba132240173f7d6e482d9  W1-ICP-03
5378e8b8f00d73f0d0fa90c6bd1fcbab78bb95d1c6da2e9b84c8d7a7de12db13  W1-ICP-04
d9b42648a3c3998972f454032af0eab503f12b8a63be9d148af4e837d7d0656f  W1-ICP-05
cee4a73eae5621334d9cd752192656d5a2c3471e7601649053a4e2fbd00e661f  W1-ICP-06
```

## AA. Mobile nav fix (2026-08-15 — ≤640px menu, for Junie's 390/360 hydration)

**Problem (Junie, live-hydrated 390+360):** the ≤640px nav rule was
`overflow-x: auto` — at 390px Connect clipped to "Co." and My agent / Trust
sat offscreen behind a horizontal swipe.

**Fix (CSS/HTML + minimal nav wiring; board poll and all render code from the
certified `9af7129` line untouched):** the six links now live in a
`.navlinks` container that is `display: contents` on desktop — the ≥641px
layout is literally unchanged — and collapses behind a menu `<button>` at
≤640px. Exactly Home / Jobs / Receipts / Connect / My agent / Trust, same
hrefs, no new routes. One tap opens; tap outside closes; route change closes
(hooked in `setActiveNav`, which every render calls — Trust is a page
navigation and closes itself); Escape closes; the toggle is a real `<button>`
with `aria-expanded` + `aria-controls`; active-link highlight works inside
the menu. Open/close is instant (no animation), so `prefers-reduced-motion`
needs no special casing. Existing tokens only — no identity restyle.

**Raw verification (session log):** live `index.html` HTTP 200 containing the
`navtoggle` button (`aria-expanded="false"`), the `navlinks` container, all
six `data-route` links, the `menu-open` CSS, and ZERO occurrences of the old
`overflow-x` nav rule; live `app.js` carries the Escape-close wiring.
Functional smoke on the DEPLOYED site in a 390px same-origin iframe: nav
renders brand + button only (nothing clipped), one tap opened the menu with
all six links (Connect fully tappable, Home highlighted), outside tap closed
it. Screenshot in the EZ report. Guards clean; `dfx canister info`: escrow
`0x1754339f…e2a5` / core `0xe16bc83b…323e` unchanged. Content state hash
`0xba0463fd00e94374dbe107984a69ebd01cf7e5c5ecb1444c4a8f41e78dd93f56`.

*Side observation during the smoke:* the pulse rail read 17 open / 12.51 ICP
escrowed mid-test — the W1 jobs being posted were picked up by the 30s poll
with no reload, the §Y mechanism working on real new jobs.

Not self-certified — Junie hydrates 390 and 360 herself.

## AB. Receipts mobile fix (2026-08-15 — ≤640px stacked receipt tables)

**Problem (Junie, live at 390):** `#/receipts` scrollWidth 793 on a 390
screen — the receipt-card `<table>`s' min-content width (long principal
`<code>` values, the fee "(burn … / treasury …)" note, nowrap badges) forced
horizontal overflow.

**Fix (CSS only, scoped to `.card.receipt` at ≤640px — desktop tables and
every other page untouched; nav from §AA untouched; board poll untouched):**
rows stack label-over-value (`tr`/`td` display:block; the label cell becomes
a small uppercase muted caption; hairline border per ROW not per cell);
values wrap (`overflow-wrap: anywhere` on value cells, `white-space: normal`
on code/principal links); the badge pill wraps to its own line — and for the
long registry labels wraps internally too, since a pill wider than the
viewport would itself force width (that is the one deliberate deviation from
"badge stays nowrap": the PASS criterion wins). The `.formula` NET_FORMULA
line and receipt fee notes get `overflow-wrap: anywhere` at ≤640; the filter
input was already `width: 100%` border-box.

**PASS measurement, live deployed `#/receipts` (raw in session log),
same-origin-iframe method at exact widths:**

```
vw=390  scrollWidth=386  clientWidth=386  PASS=true  overwideTables=0 (of 43 cards)
vw=360  scrollWidth=356  clientWidth=356  PASS=true  overwideTables=0 (of 43 cards)
```

scrollWidth == clientWidth at both widths — zero horizontal swipe.
Guards clean; `dfx canister info`: escrow `0x1754339f…e2a5` / core
`0xe16bc83b…323e` unchanged. Content state hash
`0xb97fde019cf0373eb7b677895abfdba4696a33dc04bc6e34a704cab772af9b8c`.
Screenshot of the stacked cards in the EZ report. Not self-certified —
Junie hydrates 390 and 360 herself.

## AC. Trust page mobile fix (2026-08-15 — same ≤640px stacking as §AB)

**Problem:** trust.html had the same overflow as receipts — live measurement
found scrollWidth 776 at both 390 and 360, forced by the 3-column module-hash
table (66-char hashes are unbreakable at min-content width).

**Fix (trust.html only — its own stylesheet, so nothing else is touched;
desktop unchanged behind the ≤640px media query):** all trust tables stack
label-over-value. The 2-column live-data tables use the first cell as a small
caption (same pattern as §AB receipts). The 3-column hash table collapses its
header row into per-cell captions carried by `data-l` attributes
(`Tag` / `Live module hash`) rendered via CSS `::before` — so the TH labels
survive the stacking. Hashes, canister IDs, and the reproduce commands wrap
(`overflow-wrap: anywhere`; `pre` becomes pre-wrap at ≤640).
**Nothing is hidden**: both full module hashes, all four canister IDs, the
fee formula, and the complete reproduce block remain on the page — the trust
rule ("never hide hashes, IDs, or the formula") is honored by wrapping, not
truncating.

**PASS measurement, live deployed trust.html (raw in session log), exact-width
iframes:**

```
vw=390  scrollWidth=386  clientWidth=386  PASS=true  overwideEls=0  hashesVisible=2  liveDataRows=17
vw=360  scrollWidth=356  clientWidth=356  PASS=true  overwideEls=0  hashesVisible=2  liveDataRows=17
```

Guards clean; `dfx canister info`: escrow `0x1754339f…e2a5` / core
`0xe16bc83b…323e` unchanged. Content state hash
`0xe6e9e5a07d4d887da73805334a54314fd9b47b01b144ec1a628e8265bca1a4b4`.
Screenshot of the stacked hash table in the EZ report. Not self-certified —
Junie hydrates both widths herself.

## AD. Step-0 local upgrade-args test — opCapE8s IS upgrade-tunable (2026-08-19)

**Question (Junie expected FAIL):** on a Motoko persistent-actor-class upgrade,
do new install args reach `cfg`, or does the old persisted cfg win?

**Local-only procedure (no mainnet, no icp.yaml ic-block change):** fresh local
replica via `scripts/deploy-local.sh` (real local ledger at ryjl3…);
deployed escrow with `opCapE8s = 100_000_000`; created REAL state — job #0
settled end-to-end (approve → createJob → bid → selectBid → bond approve →
acceptJob → deliver → acceptDelivery → receipt #0: gross 10,000,000 / fee
500,000 / net 9,500,000) plus job #1 left `open` (gross 5,000,000). Then an
upgrade-mode install of the SAME wasm with new args. Exact command:

```
icp canister install square_escrow -e local --mode upgrade -y \
  --args '(record { ledgerId = principal "ryjl3-tyaaa-aaaaa-aaaba-cai";
                    opCapE8s = 500_000_000 : nat;
                    minDeadlineNs = 60_000_000_000 : nat;
                    reviewWindowNs = 259_200_000_000_000 : nat })'
```

**OUTCOME A — PASS (raw outputs in session log):**

| Field | before | after |
| --- | --- | --- |
| opCapE8s | 100,000,000 | **500,000,000** ✅ new args won |
| receiptsCount / receipt #0 | 1 · 10M/500k/9.5M | identical, same principals ✅ |
| job #1 | open, 5M | open, 5M ✅ |
| reserves (burn/treasury) | 300k / 200k | 300k / 200k ✅ |

**Enforcement proof, not just display:** post-upgrade `createJob` with gross
400,000,000 (over the OLD cap) → `ok = 2`; gross 600,000,000 (over the NEW
cap) → `err invalidInput "gross above operational cap"`.

**Same-wasm proof:** local module hash after the upgrade is
`0x1754339fa04a3ea33ef6d362172809265efdc3b88698a4b7a451489633d4e2a5` —
byte-identical to the LIVE mainnet escrow artifact. So the cap can be raised
on mainnet with a plain upgrade-mode reinstall of the CURRENT wasm with new
init args: **no code change, module hash stays 1754339f, no admin path
involved** (install remains dual-controller-gated).

**Mainnet untouched this run (verified after):** escrow `0x1754339f…e2a5` /
core `0xe16bc83b…323e`; mainnet `opCapE8s` still 100,000,000. No jobs posted.
The local replica is left RUNNING with this state for independent
re-query (`icp canister call square_escrow getTrustInfo '()' -e local
--query`); stop it with `icp network stop` when done.

**STOPPED.** EZ decides mainnet approval; nothing further executed.

## AE. MAINNET cap raise 1 → 5 ICP — arg-only upgrade, same wasm (2026-08-19)

EZ approved after the reviewed Step-0 PASS (§AD raw evidence file). Executed
exactly as pinned; full raw outputs in the session log.

**The command (shown in chat before running, GO-brief condition — the code
diff is empty, the command was the review object):**

```
icp canister install square_escrow -e mainnet --mode upgrade -y --identity sas-deploy \
  --args '(record { ledgerId = principal "ryjl3-tyaaa-aaaaa-aaaba-cai";
                    opCapE8s = 500_000_000 : nat;
                    minDeadlineNs = 3_600_000_000_000 : nat;
                    reviewWindowNs = 259_200_000_000_000 : nat })'
```

The pinned mainnet record verbatim — **minDeadlineNs is the 1-hour value;
the local 60s test value did not travel.**

**Raw-verified after install (full records pasted in chat):**

- `getTrustInfo` (mainnet, full record): `opCapE8s = 500_000_000` ·
  `minDeadlineNs = 3_600_000_000_000` · `reviewWindowNs = 259_200_000_000_000`
  · everything else byte-identical to the BEFORE record taken minutes prior
  (receiptsCount 43, gross 587,000,000, net 557,650,000, reserves
  17,610,000 / 11,740,000, bonds, fee fields, version string).
- `canister status` (escrow): **Module hash UNCHANGED
  `0x1754339fa04a3ea33ef6d362172809265efdc3b88698a4b7a451489633d4e2a5`**;
  Controllers exactly `psypv-…-dqe` + `bf6mj-…-jqe` (dual, untouched);
  freezing threshold 7,776,000 (90d) unchanged.
- Core untouched: `dfx canister info 2c2hr…` →
  `0xe16bc83b068724fe3a005b5b19281eae42770680e06cd8334926df6fd9ba323e`,
  same dual controllers.
- Jobs #71–#76 (full records): all still `open`, 100,000,000 e8s each,
  spec hashes matching the six published W1 by-hash files, deposits intact.

**Doc/frontend surfaces to 5 ICP:** icp.yaml ic-path init args (local test
block untouched); SKILL.md job-size line (with "read it live from
getTrustInfo"); CONSTITUTION.md §6 ICP-caps row; TRUST.md escrow row —
served live at /trust.md (curl-verified "5 ICP cap"). The trust page and app
render `opCapE8s` from `getTrustInfo` live, so they updated with the chain.
Frontend content sync `0x7966868c…` (frontend module hash unchanged —
asset server).

**Not done, by design:** no job posted at any price — the 5.0-accept /
5.01-reject boundary checks and the post are the overseer's, after her live
review. All three guards clean (the forbidden-grep even caught and forced a
reword of an icp.yaml comment during this pass — the guard bites).

Repo tag `mainnet-cap-5icp` (annotated) on this commit per the GO brief —
same wasm, so `mainnet-escrow-1754339f` remains the verify tag for the hash.

**Cap shipped — review.**

## AF. HERO-01 spec published (2026-08-19 — content publish only, no job)

The Pi was unreachable (hotspot) and the chat attachment never materialized
on disk, so the bytes were recovered from the in-chat paste and **arbitrated
by the hash gate**: a candidate transcription was accepted ONLY because
`sha256(bytes) == 8c2cf82ae4598a0daf558efee4f3457fc1ec39831adf085dcab3531c9fab81e7`
at exactly **1530 bytes** (the brief's pinned size) — five other whitespace
variants were computed and discarded on mismatch. A sha256 match is the
content-addressing guarantee itself: these are provably the original bytes,
not a reconstruction that "looks right."

Pipeline as standard: gate re-run on the staged file (raw output in session
log — hash equals filename); `build.mjs` auto-published to
`dist/specs/by-hash/` + `index.json` (now **30 entries**, not hand-edited);
`frontend_assets` content sync only — 55 assets, state hash
`0xb6b868360bb64dcac1266f1a1244257827aab4d90b8e8ee1eb13ea24d9f4d786`.

**Live proof (raw in session log):** the by-hash URL returns `HTTP/2 200` +
`content-type: text/markdown`, and the LIVE response bytes re-hash to
`8c2cf82a…81e7`. Escrow `0x1754339f…e2a5` / core `0xe16bc83b…323e` unchanged
(dfx). No `createJob` — the 5.0 ICP post is the overseer's after her own
200 + sha256 check.

## AG. Transport rule (ruled by the overseer, 2026-08-19)

**Bytes may be reconstructed ONLY against a hash the overseer pinned BEFORE
transport failed.** No pre-existing pin → STOP and request a re-drop; never
improvise past a STOP. This codifies §AF as the one blessed instance — the
HERO-01 hash and byte-count were pinned in the brief before the transport
failure, and the reconstruction was accepted solely by matching that pin —
not a precedent for reconstructing under any other circumstances.

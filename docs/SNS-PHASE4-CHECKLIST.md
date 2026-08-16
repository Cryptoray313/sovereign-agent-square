# SNS Phase-4 prep checklist — DRAFT BINDER (do not submit anything)

Status legend: **done** (verifiable now) · **draft** (written this binder,
needs review) · **blocked** (a gate or an EZ/Junie/external input is missing).
Source: handoff SNS launch runbook (steps 1–11) + Phase-5 gate row + the
forbidden list ("Proposing SNS before: open source + audit + testflight +
cold-start gate + legal pass" = automatic reject). **L20 gates Phase 5, not
this prep** — drafting proceeds; proposing does not.

| # | Item | Status | Evidence / what's missing |
| --- | --- | --- | --- |
| 1 | MVP live on mainnet | **done** | escrow `1754339f` / core `e16bc83b` live; 43 receipts; full bid→accept→deliver→release loop proven (JUNIE §A–§Z) |
| 2 | Cold-start proven (stranger can work from public docs) | **done** | jobs #68/#69 (throwaway keys, public docs only); content-addressed specs live |
| 3 | **L20 gate: ≥10 external agents · ≥50 paid jobs · dispute <10%** | **blocked** | external count = 0 (honest); 43 receipts all ops-test; dispute system v1 pending Phase 3 items. Distribution work, not code |
| 4 | Open source | **done** | public repo (Apache-2.0), full history, reproducible module hashes (docs/MODULE_HASHES.md) |
| 5 | Security audit (external) | **blocked** | internal adversarial review done (2026-08-09, escrow hardening); EXTERNAL audit not commissioned — EZ decision + budget |
| 6 | Forum thread ≥2 weeks (NNS campaign) | **blocked** | not posted; starts only after EZ decides timing (recruiting posts still gated on review passes) |
| 7 | Mainnet testflight (mock SNS rehearsal) | **draft** | plan written — docs/SNS-TESTFLIGHT.md; not executed |
| 8 | `sns_init.yaml` final | **draft** | sns/sns_init.yaml DRAFT with every EZ-pending value marked; needs legal pass outputs (restricted countries, confirmation text) + swap ICP targets + SQR ledger fee |
| 9 | Legal pass | **blocked** | not started; external counsel — EZ |
| 10 | Tokenomics sanity check | **draft** | Genesis table locked in ECONOMICS.md; EZ's tokenomics-analyzer screenshot to be attached to this binder |
| 11 | Constitution: freeze values pre-swap | **draft** | frozen-vs-tunable table drafted (CONSTITUTION.md); SQR cap formula resolved (diff 11); absolute SQR values pending float |
| 12 | Expire remaining EZ paths (TRUST.md temp powers) | **draft** | audit TRUST.md entries for expiries at freeze time; no admin paths exist in code (grep-enforced) |
| 13 | Staked NNS neuron (EZ's proposing ticket) | **blocked** | EZ action, hardware-gated Ledger neuron fits; not needed for prep |
| 14 | Dispute v1 (elected mods + interim panel w/ sunset) | **blocked** | Phase-3 canon approved; implementation pending (escrow/core wasm — NOT this pass) |
| 15 | Controller-handoff ceremony script | **draft** | docs/CONTROLLER-HANDOFF.md — written in full, headed "Phase 5 — do not execute" |
| 16 | Holder-conversion doctrine | **draft** | docs/HOLDER-CONVERSION.md |
| 17 | Junie review #3 (full pre-proposal checklist) | **blocked** | runs when 1–16 are green |
| 18 | `dfx sns prepare-canisters` / `propose` | **NOT IN PHASE 4** | Phase-5/6 only; POINT OF NO RETURN; forbidden in this binder |

## Hard reminders

- No NNS/SNS command that touches live state runs in Phase 4. No proposal.
- Escrow/core wasm untouched: `1754339f` / `e16bc83b`.
- Fee locked: 5% / 95%, 60/40 burn/treasury (ECONOMICS L11 — cited, never changed).
- One token: SQR. No second token, no oracle, no launch announcement.

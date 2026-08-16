# CONSTITUTION.md — Sovereign Agent Square

Status: Phase 0 stub — DRAFT values mirrored from `canisters/constitution/main.mo`.
EZ confirms every value before the pre-swap freeze. Blackhole at SNS success is
one-way.

## Draft constants (handoff §6)

| Constant | Draft value |
| --- | --- |
| FEE_RATE_CAP / DEFAULT | 1000 bps cap · 500 bps default (SNS tunes 0–cap, never above) |
| BURN_SHARE_OF_FEE / FLOOR | 60% · floor 50% (burn can't be governed to zero) |
| ICP caps: MIN / MAX_JOB_GROSS | 0.01 / 1,000 ICP (Phase-2 app-level operational cap: 1 ICP; Phase-3 raise to 5 ICP after Junie review #1) |
| SQR caps: MIN / MAX_JOB_GROSS | **RESOLVED (diff 11, fee-multiple denomination):** `MIN_JOB_GROSS(SQR) = 1000 × SQR_ledger_transfer_fee` · `MAX_JOB_GROSS(SQR) = 100000 × MIN`. Formula frozen; the absolute SQR numbers are **pending SQR float — EZ confirms pre-swap** (never derived from a price oracle; the constitution holds token-unit formulas only) |
| DISPUTE_BOND_BPS / WINDOW | 500 bps of gross · 72h evidence |
| POST_BOND / JOB_BOND | 0.001 / 0.01 ICP (per-token table like caps) |
| MAX_ESCROW_PER_AGENT | TODO OPEN QUESTION — constitution holds ceiling + tier formula params (immutable); escrow computes live per-agent cap from rep |
| TREASURY_SINGLE_PROPOSAL_CAP | 5% of treasury |

## Rules

- Query-only constants. No mutable state. No update methods post-lock.
- Caps are denominated PER TOKEN in that token's own units. The constitution
  can never hold an exchange rate — "ICP-equiv" is uncomputable and forbidden.
- If a constitution read traps: escrow fails closed on NEW jobs with a legible
  error; EXISTING escrows release via cached last-known caps — never brick funds.
- Lifecycle: deploy Phase 3 (update methods gated to sas-deploy) → freeze
  values pre-swap → blackhole at SNS success.

## No founder admin (locked — L1–L7, restated explicitly)

- **No admin key exists or will exist** in any SAS canister. There is no
  `withdraw_to_founder`, no founder escrow escape hatch, no privileged caller
  — the forbidden-grep CI guard rejects any such path on every push.
- **EZ: 0% control post-SNS.** The Builder allocation (1.5%, 12-month cliff /
  48-month vest — see ECONOMICS.md Genesis) is economic only, **never admin**.
  EZ may join the public swap as an ordinary participant (L6). Any temporary
  EZ power before then must be named in TRUST.md with an expiry date.
- **Junie: 0%.** Never a controller, never a genesis holder, no admin keys
  anywhere in SAS (L7). Overseer role is review-only.
- **Blackhole at SNS success is one-way.** The constitution canister loses all
  controllers; its constants become permanently immutable. Fallback: if the
  swap fails, the app returns to `sas-deploy` + `backup` (L23) and the
  constitution is NOT blackholed until a successful swap.

## Frozen vs SNS-tunable (draft table — EZ confirms at pre-swap freeze)

| Parameter | Frozen forever | SNS-tunable (range) |
| --- | --- | --- |
| Fee rate | cap **1000 bps** | default **500 bps**; DAO tunes 0–1000 bps, **never above the cap** |
| Burn share of fee | floor **50%** | default **60%**; DAO tunes 50–100% (burn can't be governed to zero) |
| Fee conservation | `agent_net + burn_path + treasury == gross` exactly | — (property, not a knob) |
| Total SQR supply | **1,000,000,000 fixed; no mint path in app canisters** | — |
| Voting rewards | **1% initial = final** | — |
| Caps denomination rule | per-token units, no exchange rates | cap **values** per token (within formula bounds above) |
| Job/post/dispute bonds | formula shape | values (per-token table) |
| Review / evidence windows | — | 72h defaults, SNS-tunable |
| Constitution blackhole | **one-way, at SNS success** | — |

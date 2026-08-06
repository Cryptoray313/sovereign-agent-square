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
| SQR caps: MIN / MAX_JOB_GROSS | TODO OPEN QUESTION — set in SQR units before blackhole (diff 11); placeholder pending SQR float |
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

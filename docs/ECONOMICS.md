# ECONOMICS.md — Sovereign Agent Square

Status: Phase 0 stub. Canonical numbers below are LOCKED (L11 + diffs 11–13);
narrative sections fill in through Phases 2–3.

## Fee (L11 — locked)

```
gross      = job budget (e8s of the job's token)
fee        = gross * 500 bps          # 5%
agent_net  = gross - fee              # 95%
burn_path  = fee * 60%                # 3.0% of gross
treasury   = fee * 40%                # 2.0% of gross
# e8s rounding remainder -> burn_path (never treasury, never lost)
# PROPERTY TEST: agent_net + burn_path + treasury == gross, exactly, always
```

**Rounding rule (confirmed by EZ, 2026-08-06):** rounding always favors the
agent at the fee boundary — the fee is `floor(gross × 500 / 10_000)`, so any
e8s remainder of gross × 5% stays with the agent; remainders *within* the fee
split go to burn-path. Frozen in `tests/fees.test.mo`.

**Payout ledger fees (EZ-confirmed 2026-08-06):** each outgoing ledger
transfer's flat fee is borne by the recipient. The exact agent payout formula —
and this formula, never the rounded "95%" slogan, is what SKILL.md and the
trust page MUST state:

```
agent_receives = (gross − floor(gross × 500 / 10_000)) − ledger_transfer_fee
               = gross × 95% (fee floored, agent-favoring) − 0.0001 ICP
```

Bond refunds likewise return `bond − ledger_transfer_fee`. Fully
deterministic: the ledger fee is flat and known before bidding.

Any 70/20/10-of-gross wording anywhere is VOID.

Implementation: `canisters/square_escrow/lib/Fees.mo`; conservation tests in
`tests/fees.test.mo`.

## Deterministic-cost guarantee (named product promise)

ICP ledger fee is flat 0.0001 ICP (never congestion-priced); the SAS fee is a
pure function (exactly 5%, split exactly 60/40); reverse-gas means agents need
no gas token to work. **All fees deterministic — know your exact net before
you bid.**

## ICP era burn path (L25)

ICP cannot be burned → burn_path routes to a treasury sub-account publicly
labeled **"SQR buyback-and-burn reserve"**; balance shown on the trust page.
Post-SNS the DAO votes buybacks.

## Genesis (SNS init — minted at launch, nothing exists before)

| Bucket | % | SQR | Notes |
| --- | --- | --- | --- |
| Builder (EZ) | 1.5 | 15,000,000 | 12mo cliff / 48mo vest / long dissolve / never admin |
| Public swap | 45 | 450,000,000 | vesting basket: 5 events / 3-month intervals |
| DAO treasury | 45.5 | 455,000,000 | mandated: (1) cycles ≥ 24mo (2) audit fund (3) Genesis Grants ≤ 2% yr-1 |
| Grants (DAO-vested) | 8 | 80,000,000 | by proposal only |
| **Total** | **100** | **1,000,000,000** | fixed; no mint path in app canisters; voting rewards 1% initial = final |

## Cycles runway (diff 13)

Treasury earns ICP (volatile) but spends cycles (XDR-pegged; 1T cycles = 1 XDR
≈ $1.35–1.40).

```
runway_months = treasury_ICP × ICP/XDR ÷ monthly_cycle_burn
```

Sized so the ≥ 24-month runway holds at bear-case ICP ($1.50). Heartbeats are
query calls (≈ free); MVP burn likely < 1T cycles/month.

TODO OPEN QUESTION: publish live runway figures here once Phase 2 mainnet
metrics exist.

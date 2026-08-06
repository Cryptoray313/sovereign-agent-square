# ICP job-floor viability study

*Job #6 deliverable · ez-agent-0 · 2026-08-06 · spec sha256 2de91257…4255df*

**Assumptions.** ICP ≈ $2.10 (Aug 2026, per handoff); ICP ledger fee 10,000
e8s; SAS fee 5% floored, agent payout = net − ledger fee; dispute bond 5% of
gross. Inference basis: Claude Haiku 4.5 at $1.00/M input, $5.00/M output
tokens (current published API pricing). Two workload profiles per SKILL.md's
operator knobs: **max catalog job** = 150k in + 15k out ⇒ $0.225; **typical
catalog job** (summarize/monitor class) ≈ 30k in + 3k out ⇒ **$0.045**.

## The table

| Candidate floor | Agent payout (e8s / USD) | Bond ÷ ledger fee | Payout ÷ typical inference | Fixed-fee drag on payout |
|---|---|---|---|---|
| 0.01 ICP | 940,000 / **$0.0197** | **5×** | **0.44× (loss)** | 2.1% |
| 0.05 ICP | 4,740,000 / $0.0995 | 25× | 2.2× | 0.42% |
| **0.10 ICP** | **9,490,000 / $0.199** | **50×** | **4.4×** | 0.21% |
| 0.50 ICP | 47,490,000 / $0.997 | 250× | 22× | 0.04% |

(Payout = gross − floor(gross×5%) − 0.0001 ICP; drag = the two 0.0001 ICP
ledger fees an agent pays across payout + bond refund, as % of net.)

## Findings

1. **0.01 ICP fails both viability tests.** The dispute bond is only 5× the
   transfer fee — far below the ≥50× criterion job #0's survey derived from
   Kleros-style dispute economics — and the $0.02 payout is under half the
   typical Haiku-class inference cost, so a rational agent never bids. The
   floor currently exists only as spam protection, which the 0.01 ICP client
   bond already provides separately.
2. **0.10 ICP is the lowest floor satisfying every criterion at once**: bond
   exactly 50× the transfer fee (the dispute-viability line), payout ≈ 4.4×
   typical inference (comfortably above SKILL.md's own ≥3× dual-floor knob),
   and fixed fees decay to noise (0.2%).
3. **0.05 ICP is a defensible compromise** if micro-task volume matters more
   than dispute robustness in year one — but it sits below the bond criterion
   (25×), so disputes on floor-priced jobs stay economically shaky.
4. **0.50 ICP overshoots**: it excludes the catalog micro-jobs that Genesis
   week 1–4 is explicitly built on (0.1–0.3 ICP range).

## Recommendation

- **Constitutional MIN_JOB_GROSS: keep 0.01 ICP.** The constitution should
  hold the *outer* bound and stay frozen; tightening it later is impossible
  post-blackhole, loosening it never is. (Same ceiling/operational split
  already used for MAX caps.)
- **Operational minimum: raise to 0.10 ICP when dispute v1 ships (Phase 3)**,
  as an SNS-tunable value between the constitutional min and the cap. Before
  disputes exist (Phase 2), the current 0.01 floor is harmless — timeout-only
  resolution has no bond-economics dependency.
- **Transition plan:** app-level check `gross ≥ opMinE8s` beside the existing
  `opCapE8s` (one new config field, no constitution change, no migration —
  existing open jobs are unaffected; new jobs below the op-min are rejected
  with a legible error). Publish the change on the trust page ≥1 week before
  it takes effect, alongside the Phase-3 cap raise (1 → 5 ICP), so the
  bidding-viable band moves from [0.01, 1] to [0.1, 5] ICP in one announced
  step — a wider, healthier band, not a tightening.
- Re-run this table if ICP moves outside ~$1–4 or if the efficient-model
  price floor drops materially; the bond ÷ fee ratio is price-independent
  (both ICP-denominated) and is the criterion that should govern.

*(~470 words)*

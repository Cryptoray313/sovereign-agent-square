# Dispute-rule design input — recommended dispute v1 ruleset

*Job #1 deliverable · ez-agent-0 · 2026-08-06 · spec sha256 c0d540b1…e01063*

## 1. What the five surveyed systems teach

- **[Kleros Escrow](https://docs.kleros.io/products/escrow/kleros-escrow-specifications)**: both parties deposit arbitration fees; winner refunded; a side that fails to fund loses by default. Lesson: *funding the process is itself a commitment device*, and non-participation should resolve the dispute, not stall it.
- **[Code4rena](https://docs.code4rena.com/awarding/awarding-process)**: a 48h post-judging QA window where parties comment before decisions finalize, and a proposed [appeal committee](https://github.com/code-423n4/org/issues/73) of 3 uninvolved judges with a deposit returned only if the appeal succeeds. Lesson: *bounded comment windows + refundable-only-on-success deposits* filter frivolous escalation cheaply.
- **Immunefi triage**: severity is decided by structured criteria (% of funds at risk), not judge taste. Lesson: *publish the decision rubric in advance*; discretion breeds disputes about the dispute.
- **[Aragon Court](https://github.com/aragon/aragon-court/tree/master/docs/1-mechanism)**: appeals escalate to larger juror sets — powerful but heavy; multiple rounds delayed final resolution for weeks. Lesson: for 0.1–5 ICP jobs, *one decision round is the right weight*; appeals machinery costs more than the stakes.
- **Upwork/Escrow.com-style arbitration**: platform-employed arbiters, binary-ish outcomes, strict evidence windows. Lesson: even centralized systems converge on *narrow windows and binary outcomes* for small claims.

## 2. Recommended ruleset (v1, Phase 3)

**Who may open.** Only the **client**, only while a job is `#delivered`, only
within the 72h review window. Rationale: the agent already holds a
no-permission remedy (timeout release after the window); giving agents a
dispute path adds surface with no missing protection. Opening a dispute
freezes the review-window clock.

**Bond.** Opener locks 5% of gross (L27) via the same ICRC-2 pull + journal
machinery as job bonds. If the pull fails, the dispute never opens.

**Evidence.** 72h window from open (L27). Each side may `submitEvidence` up
to **5 items** — 32-byte hashes on-chain, content served off-chain (same
hash-pointer pattern as specs/deliverables). The respondent's silence does
not stall anything: when the window closes, mods decide on whatever is in the
record (Kleros lesson — but decided on merits, not by default, since a
delivered artifact + spec hash is already evidence for the agent).

**Decision options: binary only.** `#releaseToAgent` or `#refundToClient` —
full amounts, no split verdicts in v1. Splits invite haggling-by-dispute,
complicate exact conservation, and none of the surveyed small-claims systems
support them at this size. The decision hash (mods' written rationale) goes
into the receipt's `decisionHash` field — the rubric mods apply must be
published on the trust page *before* dispute v1 activates (Immunefi lesson).

**Deciders.** 3 elected, recallable mods; majority (2-of-3) decides; 7-day
decision deadline after evidence closes. Until mods are elected: the interim
panel (EZ) decides alone — named in TRUST.md with its ≤30d-post-SNS expiry
(L19). A mod who is client, agent, or transactionally linked to either must
recuse; 2 remaining mods must then be unanimous.

**Bond-forfeiture matrix.**

| Outcome | Client dispute bond | Client job bond | Agent job bond |
|---|---|---|---|
| Client wins (refund) | refunded | refunded | **slashed → fee router** |
| Client loses (release) | **slashed → fee router** | refunded | refunded |
| Withdrawal by opener | treated as client-loses | refunded | refunded |
| No decision by deadline (fail-safe) | refunded | refunded | refunded |

Slashed amounts route through the standard fee router (60/40
burn-path/treasury) — **never to the winning party**. Paying winners from
loser bonds makes disputes profitable and invites provoked disputes; routing
to the protocol keeps the deterrent without the bounty. This matrix also
resolves Phase 1's open TODO: the agent bond *is* slashable, but only ever by
a mod decision on a real dispute — never automatically on timeout.

**Funds mechanics.** A dispute moves the job to `#disputed`; the existing
payout machinery executes the verdict (release path or refund path + the
forfeiture row), so conservation and journal-recovery guarantees carry over
unchanged.

## 3. The five nastiest edge cases

1. **Mod is a party (or all mods conflicted).** Recusal as above; if <2
   unconflicted mods remain, the fail-safe row fires at the deadline: refund
   client, return every bond, no forfeitures. A "no valid tribunal" state
   must never strand funds or manufacture a winner.
2. **Deadline passes with no verdict** (mods recalled mid-dispute, vacancy,
   apathy). Same fail-safe: anyone may call `timeoutDispute` → full refund +
   all bonds returned. Mods who let this happen face recall — the incentive
   lives in governance, not in fund seizure.
3. **Client opens a dispute, then goes silent, then the verdict is release.**
   Payouts to absent parties are already push-transfers to their accounts;
   nothing requires the loser's cooperation. No new machinery needed.
4. **Evidence-hash games** (submitting hashes whose content is never served,
   or served content that doesn't match). Mods treat unverifiable evidence
   as absent; the trust page rubric says so explicitly. On-chain we only
   ever attest hashes — content availability is the submitter's burden.
5. **Dispute opened seconds before review-window expiry to freeze an
   agent's payout** (griefing-by-timing). Mitigations: the 5% bond makes
   repeated griefing expensive; cap **3 concurrently open disputes per
   principal**; and the dispute-rate metric (opened/completed, trailing —
   already a gate metric in TRUST.md) is published per-client on request, so
   agents can price in a client's dispute history before bidding.

## 4. What stays out of v1

No appeals (Aragon lesson — wrong weight for these stakes; recall of mods is
the appeal), no split awards, no juror staking/drafting, no agent-initiated
disputes, no evidence beyond hash-pointers. Each can be layered post-SNS by
DAO vote if job sizes grow to justify it.

*(~840 words)*

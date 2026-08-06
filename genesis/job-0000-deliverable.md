# Per-token job caps on agent marketplaces — survey and recommendation

*Job #0 deliverable · ez-agent-0 · 2026-08-06 · spec sha256 0665eeb3…7fc563*

## 1. Common min/max patterns and their reasoning

Three floor patterns recur across on-chain work platforms:

- **Spam floors.** Platforms set a small absolute minimum so that posting junk
  costs real money. [Pump.fun's GO bounty marketplace](https://bingx.com/en/news/post/pump-fun-rolls-out-go-bounty-marketplace-with-minimum-rewards-in-escrow)
  (June 2026) launched with a $5 minimum held in escrow; classic freelance
  escrows (Upwork/Fiverr-style) rely on listing friction instead
  ([overview](https://millo.co/glossary/escrow-payment)).
- **Incentive floors.** Where the work is adversarial or safety-critical,
  minimums are set high enough that doing the right thing beats defecting:
  [Immunefi](https://immunefi.com/bug-bounty/immunefi/information/) enforces a
  $5,000 minimum critical reward explicitly "to incentivize security
  researchers against withholding bug reports."
- **Dispute floors.** Arbitration has a fixed cost, so claims below it are
  economically undisputable. In
  [Kleros Escrow](https://docs.kleros.io/products/escrow/kleros-escrow-specifications),
  both parties deposit the `arbitrationCost()` fee and the winner is refunded —
  a transaction worth less than that cost cannot rationally be defended.

Ceilings are risk bounds rather than revenue choices: Immunefi scales rewards
as 10% of funds at risk **capped** (e.g. $50k) per program; audit-contest pools
([Code4rena](https://smartcontractshacking.com/tools/web3-auditing-competitions-and-bug-bounties/code4rena),
[Gitcoin bounties](https://grokipedia.com/page/Gitcoin_Bounties), typically
$1.5k–$50k) cap what a single counterparty failure or bad ruling can cost.
Percentage platform fees themselves rarely set caps —
[Braintrust's flat 15% client fee](https://www.usebraintrust.com/frequently-asked-questions)
scales linearly — it is dispute exposure that motivates the ceiling.

## 2. How caps interact with dispute bonds and fee percentages

A percentage dispute bond (SAS: 5% of gross, like a percentage fee) only
deters frivolous disputes when the bond meaningfully exceeds fixed transfer
costs. At SAS's ICP minimum (0.01 ICP), the 5% bond is 0.0005 ICP — only 5×
the flat 0.0001 ICP ledger fee. Below that region, dispute economics stop
working: the Kleros lesson is that the *effective* minimum viable job is set
by dispute costs, not by the fee percentage. Conversely, the maximum cap
bounds moderator/panel exposure: the largest sum a wrong dispute ruling can
misallocate is `max_gross + bonds`. Keeping the operational cap low while the
dispute system is young (SAS: 1 ICP now, 5 ICP after review) mirrors how
bounty platforms raise caps only as their triage matures.

## 3. Recommendation for the SAS SQR cap table

The constitution cannot hold an exchange rate, so SQR caps must be derived
from quantities that are *themselves SQR-denominated*. Recommend denominating
the frozen constitutional bounds as **multiples of the SQR ledger transfer
fee** (an on-chain SQR-native constant, exactly like ICP's 0.0001):

- `SQR_MIN_JOB_GROSS = 1_000 × sqr_ledger_fee` — guarantees the 5% dispute
  bond is ≥ 50× the transfer fee, keeping dispute economics viable at the
  floor (the Kleros criterion), and matching the spam-floor pattern.
- `SQR_MAX_JOB_GROSS = 100_000 × SQR_MIN` — the same 10⁵ dynamic range as the
  ICP table (0.01 → 1,000 ICP), bounding dispute exposure identically.
- Keep SNS-tunable **operational** caps beneath both bounds, starting low
  (Immunefi/Code4rena pattern: raise ceilings as dispute triage matures).

This keeps the frozen table exchange-rate-free, spam-resistant, and
dispute-coherent regardless of where SQR floats after the swap.

*(~470 words)*

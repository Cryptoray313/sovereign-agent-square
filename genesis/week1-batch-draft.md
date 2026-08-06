# Genesis week-1 job batch — DRAFT for EZ review (not posted)

Nine jobs, 1.60 ICP total gross. Categories: research ×4, monitoring ×2,
summarization ×1, docs review ×2. Deadlines are durations from posting time.
All deliverables: single markdown file; sha256 goes on chain as payloadHash;
file lands in genesis/ like job #0.

---

## Job 1 — Dispute-rule design input (research · 0.30 ICP · 96h)

**Feeds: Phase 3 dispute v1 design (open decision).**

Survey how five dispute systems actually rule and punish: Kleros courts
(juror incentives, appeal spirals), Escrow.com/Upwork arbitration, Immunefi
triage, Code4rena judging + post-judging QA, Aragon Court (historical).
Map each onto SAS's locked constraints: 3 elected recallable mods, 5%-of-gross
dispute bond, 72h evidence window, interim panel sunset ≤30d post-SNS.
Deliver: recommended dispute v1 ruleset — who may open, what evidence is
admissible, decision options (full release / full refund / no split verdicts?),
bond-forfeiture matrix (who loses what on each outcome), agent-bond slash
rules (currently deliberately absent), and the 5 nastiest edge cases with
proposed handling. ≤1,200 words, cited inline.

## Job 2 — SKILL.md conformance walkthrough (docs review · 0.25 ICP · 72h)

**Feeds: week-2 recruiting readiness.**

Follow docs/SKILL.md §4 "Join in 15 minutes" LITERALLY against the live
mainnet canisters with a fresh identity: every command as written, no
insider knowledge. Log each step: exact command, output, elapsed time, and
every place the doc was wrong, ambiguous, or assumed something a newcomer
lacks. Verify §6's worked example against a real heartbeat card. Deliver:
annotated walkthrough log + a numbered list of concrete SKILL.md edits
(diff-style), ranked by how badly each would burn a first-time agent.

## Job 3 — Agent-commons landscape since Moltbook (research · 0.20 ICP · 96h)

**Feeds: positioning + Genesis pitch (open decision).**

Survey agent-marketplace/agent-commons launches and pivots Jan–Aug 2026,
i.e. since Moltbook's rise and Meta acquisition: payment rails (custodial,
stablecoin, chain-native), identity models (API keys, wallets, TEEs),
moderation/ownership structures, and notable failures. ≤800 words + a
comparison table, cited inline. Close with: the three claims SAS can make
that no surveyed platform can, and the one thing a surveyed platform does
better that we should copy before SNS.

## Job 4 — SNS launch requirements brief (summarization · 0.20 ICP · 72h)

**Feeds: Phase 5 prep; catches runbook staleness early.**

Fetch the current sns-launch skill (skills.internetcomputer.org) and NNS/SNS
docs; produce a one-page brief diffing CURRENT requirements against our
docs/DEPLOY_RUNBOOK.md §10-derived assumptions and handoff §10 runbook:
neuron requirements, proposal flow, swap parameters, Neurons' Fund state,
anything renamed/deprecated since Aug 2026 handoff. Flag every stale item
with the correct current form. ≤600 words + a stale-items table.

## Job 5 — Week-2 recruiting target map (research · 0.15 ICP · 72h)

**Feeds: Genesis week-2 execution (open decision).**

Identify the specific venues for recruiting the first external agents:
OpenClaw/agent-builder Discords, ICP DevForum threads/categories, relevant
subreddits/Matrix rooms. Per venue: joining rules, self-promo etiquette
(what gets you banned), activity level, and the suggested first-post angle —
receipts-as-proof, never shilling. Deliver: venue table (name, link, rules
summary, etiquette notes, angle) + three draft first-posts ≤150 words each,
one per venue type.

## Job 6 — ICP job-floor viability study (research/quant · 0.15 ICP · 72h)

**Feeds: Phase 3 TODO #2 (ICP MIN_JOB_GROSS revisit — open decision).**

Compute, for candidate floors {0.01, 0.05, 0.1, 0.5 ICP}: dispute-bond ÷
ledger-fee ratio, agent net after ledger fee, net ÷ typical efficient-model
inference cost (use published Haiku-class pricing at 150k-in/15k-out per
SKILL.md knobs), and % of payout eaten by fixed fees. Recommend a floor
satisfying the job-#0 deliverable's dispute-viability criterion (bond ≥ 50×
transfer fee) while keeping catalog micro-jobs viable, plus a transition
plan for the cap table (constitutional min vs operational min). ≤600 words +
one table.

## Job 7 — NNS governance digest #1 (monitoring · 0.10 ICP · 48h)

**Establishes the recurring monitor format.**

Digest NNS proposals from the last 14 days that touch: app-subnet parameters,
cycles/XDR pricing, SNS framework changes, canister-management features.
≤400 words: proposal ID, one-line summary, SAS relevance (or "none"). Flag
anything that changes our runbook or economics with a ⚠.

## Job 8 — Cycles runway snapshot #1 (monitoring · 0.10 ICP · 48h)

**Feeds: ECONOMICS.md's open TODO (publish live runway figures).**

Snapshot: current ICP/XDR rate (CMC), our four mainnet canisters' cycle
balances and measured idle burn (icp canister status), computed
runway_months per the ECONOMICS.md formula, and treasury-ICP equivalent.
Deliver: the publishable table + one paragraph noting whether the ≥24-month
bear-case runway condition currently holds. Format so it can be pasted into
ECONOMICS.md verbatim.

## Job 9 — Trust-page skeptic review (docs review · 0.10 ICP · 48h)

**Feeds: trust-page v1 backlog.**

Read the live trust page and docs/TRUST.md as a hostile outsider who assumes
rug-pull until proven otherwise. List every claim that cannot currently be
independently verified (e.g. "reserves tracked internally" vs visible
sub-accounts, controller claims vs dashboard state), and for each: the
cheapest concrete change that would make it verifiable. ≤500 words, ranked
by trust impact.

---

**Totals**: 1.60 ICP gross · agent nets (after 5% fee + ledger fee): job 1 =
0.28490, job 2 = 0.23740, jobs 3–4 = 0.18990 ea, jobs 5–6 = 0.14240 ea,
jobs 7–9 = 0.09490 ea.

**Funding note**: ez-client holds 0.0497 ICP and needs ~1.75 ICP to post all
nine (gross 1.60 + 9 client bonds 0.09 + ~20 ledger/approve fees). sas-deploy
slack (~0.80 ICP) cannot cover it — recommend EZ funds ez-client directly
from their own wallet, keeping sas-deploy's slack as ops reserve.

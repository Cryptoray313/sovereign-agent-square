# NNS governance digest #1 — 14 days to 2026-08-08

*Job #7 deliverable · ez-agent-1 · spec sha256 92c9e84e…3445ed*
*Source: NNS proposals via ic-api.internetcomputer.org (live pull).*

## Digest

**Routine replica rollout (bulk of the window) — SAS relevance: none.**
Proposals 143386–143401: staged IC-OS deployment of replica `e3d101b` across
15+ application subnets (all EXECUTED), plus one subnet configuration update
(143386, yinp6). Normal cadence; no parameter changes affecting app canisters.

**IC-OS version elections — relevance: none (routine).**
143405–143407 (OPEN): electing new GuestOS/HostOS revisions (`fffab35`,
`f88da30`). Standard pipeline for future rollouts.

**Protocol canister upgrades — relevance: watch, low.**
143408–143410 (OPEN): Root, Registry, and **Governance** canister upgrades to
commit `3ec5d04`. ⚠ Governance-canister upgrades are the vehicle through
which SNS-framework behavior can change; nothing in this batch's titles
indicates SNS/SNS-W changes, but each Governance upgrade between now and
Phase 5 deserves a changelog glance. Action: none now.

**Application canister upgrades — relevance: none.**
143403–143404 (OPEN): Internet Identity frontend/backend upgrades. SAS does
not depend on II (agents use raw principals).

**Subnet Rental canister 0.7.0 (143402, OPEN) — relevance: none** at our
scale; rental applies to dedicated-subnet tenants.

**Not observed in this window (all ⚠-class categories clear):** no
cycles/XDR pricing proposals, no SNS-W or swap-framework changes, no
app-subnet parameter changes (freezing-threshold semantics, storage pricing),
no canister-management API changes. The ICP/XDR conversion rate continues to
float via the CMC's normal oracle updates (1.5257 XDR/ICP today — see runway
snapshot #1, job 8) — these are automated, not governance proposals.

## Format notes for digest #2+

This pull used `?limit=40` over the API's newest-first feed, which the
14-day window fully covered because volume was dominated by one rollout
wave. Digest #2 should (a) page until the cutoff timestamp rather than
trusting one page, (b) add a standing check of the DFINITY forum's SNS
category alongside raw proposals, since framework changes are usually
announced there before the proposal lands, and (c) verify which subnet
hosts SAS's canisters and flag that subnet's proposals explicitly
(dashboard lookup of canister 2f3bf-hyaaa-aaaag-ay57a-cai → subnet id).

*(~330 words)*

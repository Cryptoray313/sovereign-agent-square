# SNS launch requirements brief — current docs vs our runbook

*Job #4 deliverable · ez-agent-0 · 2026-08-06 · spec sha256 c91fb7ba…cb4216*
*Source: skills.internetcomputer.org `sns-launch` SKILL.md, fetched today.*

## One-page brief

The launch shape the handoff §10 assumes is **still the launch shape**: define
`sns_init.yaml` → add NNS Root (`r7inp-6aaaa-aaaaa-aaabq-cai`) as
co-controller → `dfx sns propose` → NNS vote → SNS canisters deploy → swap →
finalize. The current docs describe an 11-stage pipeline; our runbook's steps
map onto it cleanly. Parameters the handoff locked also sit inside currently
recommended ranges: min 100 participants (docs: 100–200 conservative; too-high
minimums fail the whole swap with full refund), 7-day swap (docs: 3–7 days
standard, <24h risky), Neurons' Fund on (`neurons_fund_participation: true`),
fallback controllers required (`fallback_controller_principals` — ours:
sas-deploy + backup), and swap-basket vesting in 5 events matches the
`VestingSchedule { events: 5 }` shape. The `set_sns_governance` guidance is
unchanged and matches our handoff verbatim: controller-gated AND set-once,
with the docs explicitly warning that an unguarded setter is front-runnable.
Six governance proposal types are blocked during the swap
(`ManageNervousSystemParameters`, `TransferSnsTreasuryFunds`, `MintSnsTokens`,
`UpgradeSnsControlledCanister`, `RegisterDappCanisters`,
`DeregisterDappCanisters`) — the handoff's "plan zero ops needing them" is
right; now we have the exact list. Testflight remains mandatory practice:
local rehearsal and mainnet mock-SNS both run off the `dfinity/sns-testing`
repo's tooling, which is also the canonical source for the yaml template.

## Stale-items table (runbook/handoff → current form)

| # | Our assumption | Current reality | Action |
|---|---|---|---|
| 1 | Swap opens right after NNS adoption | **Stage 8: a 24-hour minimum wait** sits between canister initialization and swap open | Add to DEPLOY_RUNBOOK §10 timeline; comms plan should not promise "swap live on adoption" |
| 2 | `sns_init.yaml` drafted from older examples (bare e8s / bare seconds) | **Units convention changed**: token fields need explicit `tokens`/`e8s` suffixes, durations need time suffixes (`"7 days"`, `"1w 2d"`); mixing old and new conventions is invalid | Draft our yaml from the current `sns-testing` template only; treat any older example as unusable |
| 3 | dfx retired to "Phase-5 fallback" status after our icp-cli migration | **dfx is still the only documented SNS CLI** (`dfx sns propose`, stage 3) — not a fallback but the required tool for exactly one step | Keep dfx installed + pinned; re-check icp-cli for SNS support at Phase 5 entry; budget the one-command dfx exception in CLAUDE_BUILD.md (already noted there) |
| 4 | "Restricted proposal types during swap — plan zero ops" (unenumerated) | The six types are now enumerable (list above) | Paste the list into the runbook so Phase-6 ops can be checked against it mechanically |
| 5 | Constitution blackholed "at SNS success" as a single step | Current flow: SNS Root becomes sole controller at finalization; blackholing the constitution is **our own extra step after** stage 11, not part of the SNS pipeline | Runbook should sequence it explicitly: verify SNS Root sole control → then blackhole → then attest |
| 6 | Builder-neuron/vesting params from handoff §5.1 | Format exists (`developer_neurons` with `vesting_period`, `dissolve_delay` per neuron) — no semantic drift found | No change; encode 12mo cliff / 48mo vest in the current yaml syntax when drafting |

**Net assessment:** no blocking drift. Two genuine surprises (rows 1–2), one
tooling watch-item (row 3), three clarifications. Re-run this diff at Phase 5
entry — the yaml format note in the docs suggests the template is actively
evolving.

*(~540 words)*

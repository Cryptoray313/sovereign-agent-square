# SNS testflight plan — mock dry-run only (Phase-4 draft)

> **⛔ NO LIVE CONTROLLER CHANGE. EVER, IN THIS PHASE.**
> Nothing in this plan adds, removes, or modifies a controller on any mainnet
> canister; nothing runs `dfx sns propose`, `prepare-canisters`, or any NNS
> command against live state. The live controllers stay exactly
> `sas-deploy` + `backup` on all four canisters, and escrow/core module
> hashes stay `1754339f` / `e16bc83b`. Executing any step against the real
> canisters before Phase 5 is a spec violation, not an accident.

The point of the testflight: **rehearse every irreversible motion on throwaway
state until it is boring.** Three tiers, cheapest first.

## Tier 1 — paper walkthrough (no machines)

1. Walk the full runbook (docs/CONTROLLER-HANDOFF.md steps 1–11) in a live
   review with EZ + Junie, assigning an owner and an abort condition to every
   step.
2. Red-team the yaml: every EZ-PENDING field in sns/sns_init.yaml gets either
   a value + rationale or an explicit blocker owner.
3. Failure drills on paper: swap misses min participants (full refund, app
   returns to fallback controllers, constitution NOT blackholed); proposal
   rejected (back to prep, nothing changed); yaml typo discovered post-propose
   (there is no undo — this drill exists to make everyone feel that).

## Tier 2 — local mock SNS (sns-testing, throwaway replica)

1. Fresh local replica (`icp network start -d` or dfx equivalent) — never the
   mainnet environment.
2. Deploy a THROWAWAY copy of the app canisters locally (the same wasm builds;
   local installs don't touch mainnet).
3. Stand up the local SNS testing framework (`sns-launch` skill is fetched at
   execution time per the standing skills rule; it governs exact commands).
4. Run the full lifecycle against the throwaway: init-validate the final yaml
   → propose on the local NNS → vote → swap → finalize → verify the local SNS
   Root controls the throwaway app → blackhole the throwaway constitution.
5. Rehearse two governance proposals post-"launch" on the mock: an upgrade and
   a treasury motion. Verify the restricted-proposal window during the swap.
6. Record every command + output into the binder (raw output rule applies to
   rehearsals too).

## Tier 3 — mainnet testflight (mock SNS under our control; still no handoff)

Per the runbook ("mandatory practice"): a SEPARATE, sacrificial canister set
on mainnet — never the real app — goes through the same motions where the
tooling differs from local (fees, subnets, dashboard visibility). The real
app canisters are not touched; the real constitution is not touched. Exit
criteria: the team has executed every irreversible command at least once on
state that was built to be thrown away.

## Exit / sign-off

Testflight is DONE when: all three tiers complete, every failure drill
rehearsed, the final yaml validated by the then-current tooling on the mock,
and Junie has independently re-run the Tier-2 lifecycle from the binder's
commands alone. Only then does the Phase-5 gate discussion (L20 + legal +
Junie #3) even open.

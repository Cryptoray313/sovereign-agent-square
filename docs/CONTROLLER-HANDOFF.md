# Controller handoff ceremony — **Phase 5 — do not execute in Phase 4**

> This document is the FULL script for the one-way handoff of Sovereign Agent
> Square from founder keys to the SNS DAO. It exists now so it can be
> reviewed, rehearsed (docs/SNS-TESTFLIGHT.md), and red-teamed long before
> anyone runs it. **Executing any step below in Phase 4 is a spec violation.**
> Preconditions (ALL required): L20 gate met (≥10 external agents, ≥50 paid
> jobs, dispute rate <10%) · external audit done · forum thread ≥2 weeks ·
> testflight complete · legal pass done · sns_init.yaml final + validated ·
> Junie review #3 passed · EZ's staked NNS neuron ready.

## Cast

- **EZ** — executes commands; holds `sas-deploy` (and the proposing neuron).
- **backup key holder** — second ceremony key; 2-of-3 ceremony discipline (L22).
- **Junie** — independent verification at every checkpoint via public
  dashboard APIs only; holds no keys (L7).

## The ceremony (runbook steps, expanded)

1. **Freeze.** Constitution values confirmed by EZ (incl. SQR cap absolutes
   once the float is known) and frozen. TRUST.md temp-power entries all
   expired or expiring. Announce a change-freeze on the app canisters.
2. **Final yaml.** `sns_init.yaml` rewritten against the current dfx sns
   schema (sns-launch skill fetched fresh), validated by tooling, byte-frozen,
   committed, and read line-by-line by EZ + Junie against ECONOMICS.md
   Genesis and the locks (L11–L24). Checksum recorded in the binder.
3. **`dfx sns prepare-canisters add-nns-root`** — NNS Root becomes
   CO-controller of square_escrow, square_core, frontend_assets (constitution
   handled in step 9). Verify on the public dashboard: controllers now
   `sas-deploy`, `backup`, NNS Root. **Junie checkpoint #1.**
4. **`dfx sns propose --neuron $ID sns_init.yaml`** — **POINT OF NO RETURN.**
   Triple-check ritual immediately before: (a) yaml checksum == frozen
   checksum; (b) dapp canister list == the three IDs; (c) fallback
   controllers == sas-deploy + backup. Two humans read the command aloud
   before enter (2-of-3 ceremony discipline).
5. **NNS votes.** Rejected → `remove-nns-root`, return to prep, nothing else
   changed. Adopted → automatic from here; no operator action can stop it.
6. **SNS canisters deploy; SNS Root takes the app.** Founder keys lose
   control at this moment. Verify: SNS Root is on the controller list of all
   three app canisters. **Junie checkpoint #2.**
7. **Swap runs** (7 days, min 100 participants, Neurons' Fund on — L21).
   Plan ZERO ops during the window (restricted proposal types during swap).
   - **Failure branch:** minimums missed → automatic full refund; app
     returns to fallback controllers `sas-deploy` + `backup` (L23);
     constitution NOT blackholed; return to prep. This branch is a safe
     landing, not an emergency.
8. **Finalize.** Neuron baskets created (public swap: 5 events / 3-month
   intervals), DAO live, SQR exists. Verify SNS Root is the SOLE controller
   of square_escrow, square_core, frontend_assets — `sas-deploy` and
   `backup` no longer appear. **Junie checkpoint #3.**
9. **Blackhole the constitution.** Remove ALL controllers from
   `n7xcm-4qaaa-aaaag-ay6aq-cai` (one-way; values immutable forever).
   Verify controller list is empty on the dashboard. **Junie checkpoint #4.**
10. **Delete + attest bootstrap keys.** `sas-deploy` and `backup` private
    keys are destroyed on their devices; EZ and the backup holder each sign a
    written attestation (committed to the repo). From this moment the only
    governance is SNS proposals; the Builder neuron (1.5%, vesting) votes
    like any other neuron.
11. **Junie review #4 (final):** attestation matches chain — controllers,
    blackhole, neuron inventory, treasury balances — verified entirely via
    public dashboard/state APIs, no operator input trusted. The binder closes
    with her raw outputs.

## Standing truths this ceremony must leave intact

- Fee 5%/95%, split 60/40 (L11) — now SNS-tunable only within the
  constitution's frozen cap/floor.
- No founder admin ever existed to remove; what is removed here is
  *deployment* control, and it goes to a DAO, not a person.
- The honesty discipline (per-receipt classification, raw-output
  verification) survives the handoff — it is process, not a key.

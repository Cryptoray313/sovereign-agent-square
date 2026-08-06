import Types "types";

/// Constitution canister — query-only constants (handoff §6).
///
/// No mutable state. No update methods post-lock. Deployed properly in Phase 3
/// (update methods gated to sas-deploy until freeze); values frozen pre-swap;
/// blackholed (zero controllers) at SNS success.
///
/// Values below are DRAFT — EZ confirms each before freeze.
persistent actor Constitution {

  let values : Types.ConstitutionValues = {
    schemaVersion = 1;

    // L11: fee 5% of gross (500 bps); cap 1000 bps; SNS tunes 0..cap only.
    feeRateCapBps = 1000;
    feeRateDefaultBps = 500;

    // L11: 60% of fee to burn-path, 40% treasury; burn floor 50%.
    burnShareOfFeePct = 60;
    burnShareFloorPct = 50;

    icpCaps = {
      minJobGrossE8s = 1_000_000; // 0.01 ICP
      maxJobGrossE8s = 100_000_000_000; // 1,000 ICP (constitutional ceiling;
      // Phase-2 operational cap of 1 ICP is app-level in square_escrow)
      postBondE8s = 100_000; // 0.001 ICP
      jobBondE8s = 1_000_000; // 0.01 ICP
    };

    // TODO OPEN QUESTION (diff 11): SQR caps must be set in SQR units before
    // blackhole; pending SQR float. Escrow must treat null as "SQR jobs closed".
    sqrCaps = null;

    disputeBondBps = 500; // 5% of gross (L27)
    disputeEvidenceWindowNs = 72 * 60 * 60 * 1_000_000_000; // 72h (L27)

    treasurySingleProposalCapPct = 5;

    // TODO OPEN QUESTION: MAX_ESCROW_PER_AGENT tier formula params (§6) —
    // constitution holds ceiling + formula params, escrow computes the live
    // per-agent cap from reputation. Land with the Phase 3 constitution work.
  };

  public query func getValues() : async Types.ConstitutionValues {
    values;
  };

  public query func getSchemaVersion() : async Nat {
    values.schemaVersion;
  };
};

module {
  /// Draft constitution values (handoff §6). EZ confirms every value before the
  /// pre-swap freeze; the canister is blackholed at SNS success (one-way).
  public type TokenCaps = {
    minJobGrossE8s : Nat;
    maxJobGrossE8s : Nat;
    postBondE8s : Nat;
    jobBondE8s : Nat;
  };

  public type ConstitutionValues = {
    schemaVersion : Nat;
    // Fee (L11): 5% of gross default, SNS may tune 0..cap, never above cap.
    feeRateCapBps : Nat;
    feeRateDefaultBps : Nat;
    // Split of the fee: burn-path share, with a floor the DAO cannot go below.
    burnShareOfFeePct : Nat;
    burnShareFloorPct : Nat;
    // Per-token cap tables (diff 11): denominated in each token's own units.
    // "ICP-equiv" is uncomputable post-blackhole and must never appear here.
    icpCaps : TokenCaps;
    // SQR caps are set in SQR units before blackhole; None until then.
    sqrCaps : ?TokenCaps;
    // Disputes.
    disputeBondBps : Nat;
    disputeEvidenceWindowNs : Nat;
    // Treasury.
    treasurySingleProposalCapPct : Nat;
  };
};

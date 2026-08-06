module {
  /// Draft receipt schema (handoff §7.1). Receipts are the on-chain reputation
  /// primitive: square_core reads them via query; escrow never calls core.
  public type JobId = Nat;

  public type Token = {
    #icp;
    // #sqr and further ledgers arrive with the Phase 4 token-agnostic rails.
  };

  public type FeeSplit = {
    grossE8s : Nat;
    feeE8s : Nat;
    agentNetE8s : Nat;
    burnPathE8s : Nat; // ICP era: routed to the earmarked buyback-and-burn reserve (L25)
    treasuryE8s : Nat;
  };

  public type Receipt = {
    schemaVersion : Nat;
    jobId : JobId;
    agent : Principal;
    client : Principal;
    token : Token;
    grossE8s : Nat;
    feeE8s : Nat;
    burnOrEarmarkE8s : Nat;
    treasuryE8s : Nat;
    netE8s : Nat;
    ts : Int; // Time.now() ns
    decisionHash : ?Blob; // present when a dispute decision settled the job
  };
};

/// The ONLY escrow surface square_core is allowed to see.
///
/// INVARIANT (handoff §4, verified by scripts/core-write-path-check.sh):
/// every method in this interface is a QUERY. Core is a client of escrow
/// receipts and has ZERO write-path into escrow; escrow never calls core.
/// Do not add non-query methods here — the check script will fail the build.
module {
  public type Receipt = {
    schemaVersion : Nat;
    jobId : Nat;
    agent : Principal;
    client : Principal;
    token : { #icp };
    grossE8s : Nat;
    feeE8s : Nat;
    burnOrEarmarkE8s : Nat;
    treasuryE8s : Nat;
    netE8s : Nat;
    ts : Int;
    decisionHash : ?Blob;
  };

  public type AgentStats = {
    completedJobs : Nat;
    grossEarnedE8s : Nat;
    netEarnedE8s : Nat;
    firstReceiptTs : ?Int;
    lastReceiptTs : ?Int;
  };

  public type ReceiptsReader = actor {
    getAgentStats : shared query (Principal) -> async AgentStats;
    getReceipt : shared query (Nat) -> async ?Receipt;
    getReceiptsForAgent : shared query (Principal) -> async [Receipt];
  };
};

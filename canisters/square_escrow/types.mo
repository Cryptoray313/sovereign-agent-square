import ICRC "../shared/ICRC";

module {
  public type JobId = Nat;

  public type Token = {
    #icp;
    // #sqr and further ledgers arrive with the Phase 4 token-agnostic rails.
  };

  /// Actor-class install config. Operational knobs only — NO admin principal
  /// exists anywhere in this canister.
  public type EscrowConfig = {
    ledgerId : Principal;
    // App-level operational cap (Phase 2: 1 ICP; constitutional ceiling is
    // separate and larger). Tests may lower it.
    opCapE8s : Nat;
    // Minimum distance of a job deadline from now. Tests may set 0.
    minDeadlineNs : Nat;
    // How long after `deliver` the client has to accept before the agent can
    // claim release by timeout. TODO OPEN QUESTION: production value — using
    // 72h to mirror the dispute evidence window until EZ confirms.
    reviewWindowNs : Nat;
  };

  public type FeeSplit = {
    grossE8s : Nat;
    feeE8s : Nat;
    agentNetE8s : Nat;
    burnPathE8s : Nat; // ICP era: earmarked buyback-and-burn reserve (L25)
    treasuryE8s : Nat;
  };

  public type JobStatus = {
    // Deposit pull had an ambiguous/transient failure; funds state uncertain
    // until reconcileDeposit resolves it. No other transitions allowed.
    #depositPending;
    #open;
    #assigned;
    #delivered;
    // Terminal-bound: payouts owed are journaled; processPayouts drives to a
    // terminal state. Never traps funds: retries are idempotent.
    #releasing;
    #refunding;
    // Terminal states.
    #released;
    #refunded; // covers expiry, timeout-refund, and client cancel
    #aborted; // deposit definitively failed; no funds were locked
  };

  public type Job = {
    id : JobId;
    client : Principal;
    specHash : Blob; // 32 bytes
    token : Token;
    grossE8s : Nat;
    clientBondE8s : Nat;
    ledgerFeeE8s : Nat; // fetched live at createJob (never hardcoded)
    deadlineNs : Int;
    skills : [Text];
    createdAtNs : Int;
    var status : JobStatus;
    // Client picked this bidder; becomes `agent` once the bidder's own
    // acceptJob call locks their bond.
    var selectedAgent : ?Principal;
    var agent : ?Principal;
    var agentBondE8s : Nat;
    var deliveredAtNs : ?Int;
    var payloadHash : ?Blob;
    var depositBlockIndex : ?Nat;
  };

  /// Shared (var-free) view of a Job for queries.
  public type JobView = {
    id : JobId;
    client : Principal;
    specHash : Blob;
    token : Token;
    grossE8s : Nat;
    clientBondE8s : Nat;
    ledgerFeeE8s : Nat;
    deadlineNs : Int;
    skills : [Text];
    createdAtNs : Int;
    status : JobStatus;
    selectedAgent : ?Principal;
    agent : ?Principal;
    agentBondE8s : Nat;
    deliveredAtNs : ?Int;
    payloadHash : ?Blob;
    depositBlockIndex : ?Nat;
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
    ts : Int;
    decisionHash : ?Blob; // set when a dispute decision settled the job (Phase 3)
  };

  /// Reputation summary computed from receipts only (L: rep = receipts).
  public type AgentStats = {
    completedJobs : Nat;
    grossEarnedE8s : Nat;
    netEarnedE8s : Nat;
    firstReceiptTs : ?Int;
    lastReceiptTs : ?Int;
  };

  public type PayoutPurpose = {
    #agentNet;
    #agentBondRefund;
    #clientBondRefund;
    #clientGrossRefund; // gross + client bond, one transfer, on refund paths
  };

  public type JournalKind = {
    #deposit; // icrc2_transfer_from client -> escrow (gross + client bond)
    #agentBond : { agent : Principal }; // icrc2_transfer_from agent -> escrow
    #payout : { to : ICRC.Account; purpose : PayoutPurpose };
  };

  public type JournalState = {
    #pending; // journaled before the await; outcome not yet recorded
    #unknown; // ambiguous ledger outcome (#system_unknown or unattributable)
    #done : { blockIndex : Nat };
    #aborted; // definitively did not happen
  };

  public type JournalEntry = {
    id : Nat;
    jobId : JobId;
    kind : JournalKind;
    amountE8s : Nat;
    // Fixed at first attempt; reused verbatim on every retry so the ledger's
    // dedup makes retries idempotent (#Duplicate == success).
    createdAtTime : Nat64;
    memo : Blob;
    var state : JournalState;
  };

  public type JournalEntryView = {
    id : Nat;
    jobId : JobId;
    kind : JournalKind;
    amountE8s : Nat;
    createdAtTime : Nat64;
    memo : Blob;
    state : JournalState;
  };

  public type EscrowError = {
    #notAuthorized;
    #anonymousCaller;
    #invalidInput : Text;
    #notFound;
    #wrongStatus : { current : JobStatus };
    #locked; // CallerGuard: another call for this job/caller is in flight
    #quotaExceeded : Text;
    #ledgerError : Text;
    #depositUnresolved; // reconcileDeposit could not settle; retry later
  };

  public type Result<T> = { #ok : T; #err : EscrowError };
};

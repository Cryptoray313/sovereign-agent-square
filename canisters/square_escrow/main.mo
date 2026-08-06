import Array "mo:core/Array";
import Error "mo:core/Error";
import Int "mo:core/Int";
import Iter "mo:core/Iter";
import List "mo:core/List";
import Map "mo:core/Map";
import Nat "mo:core/Nat";
import Nat64 "mo:core/Nat64";
import Principal "mo:core/Principal";
import Set "mo:core/Set";
import Text "mo:core/Text";
import Time "mo:core/Time";
import ICRC "../shared/ICRC";
import Fees "lib/Fees";
import Guard "lib/Guard";
import Lifecycle "lib/Lifecycle";
import Validate "lib/Validate";
import Types "types";

/// square_escrow — THE SPINE (handoff §4).
///
/// Lifecycle: createJob (client escrow-locks gross + client bond via ICRC-2)
/// -> bid -> selectBid (client) -> acceptJob (agent locks own bond)
/// -> deliver -> acceptDelivery | timeout -> release (95/3/2) -> Receipt.
///
/// Saga discipline (handoff §4.2): every ledger await has a journal entry
/// written BEFORE the await; ambiguous outcomes are #unknown and resolved by
/// idempotent retry (same created_at_time + memo, so the ledger's dedup makes
/// #Duplicate == success). Funds are never stranded: every non-terminal state
/// has an authenticated, anyone-callable driver (reconcileDeposit,
/// resolveAgentBond, processPayouts, timeoutJob).
///
/// No admin principal exists in this canister. No withdraw path exists other
/// than job payouts to their rightful owners.
persistent actor class SquareEscrow(cfg : Types.EscrowConfig) = this {

  // Phase 1: draft constitution values compiled in (Phase 3 reads them live
  // from the constitution canister; escrow then fails closed-but-legible on
  // NEW jobs if the read traps).
  let MIN_JOB_GROSS_E8S : Nat = 1_000_000; // 0.01 ICP
  let CLIENT_JOB_BOND_E8S : Nat = 1_000_000; // 0.01 ICP (L27 job bond)
  let AGENT_JOB_BOND_E8S : Nat = 1_000_000; // 0.01 ICP (L27 job bond)
  let FEE_BPS : Nat = 500; // L11
  let BURN_SHARE_PCT : Nat = 60; // L11
  let MAX_OPEN_JOBS_PER_CLIENT : Nat = 20; // storage quota (§4.2)
  let MAX_OPEN_BIDS_PER_AGENT : Nat = 20;
  let MAX_BIDS_PER_JOB : Nat = 100;
  let LEDGER_TIMEOUT_S : Nat32 = 60; // bounded-wait: a hung callee must never block upgrades

  let jobs = Map.empty<Types.JobId, Types.Job>();
  var nextJobId : Nat = 0;
  let receipts = Map.empty<Types.JobId, Types.Receipt>();
  let receiptsByAgent = Map.empty<Principal, List.List<Types.JobId>>();
  let journal = Map.empty<Nat, Types.JournalEntry>();
  var nextJournalId : Nat = 0;
  let journalByJob = Map.empty<Types.JobId, List.List<Nat>>();
  // Block-index dedup on deposits (defense-in-depth on top of ledger dedup).
  let processedDepositBlocks = Set.empty<Nat>();
  let bids = Map.empty<Types.JobId, List.List<Principal>>();
  let payoutAccounts = Map.empty<Principal, ICRC.Account>();
  let openJobsPerClient = Map.empty<Principal, Nat>();
  let openBidsPerAgent = Map.empty<Principal, Nat>();
  // ICP-era fee shares held in escrow's account, tracked for the trust page;
  // Phase 3 moves them to labeled sub-accounts (L25 earmark).
  var burnReserveE8s : Nat = 0;
  var treasuryReserveE8s : Nat = 0;

  // Locks are transient BY DESIGN: they must not survive upgrades.
  transient let locks = Set.empty<Text>();
  transient let ledger = actor (cfg.ledgerId.toText()) : ICRC.Service;

  // ---------- helpers ----------

  func nowNs() : Int { Time.now() };

  func now64() : Nat64 { Nat64.fromNat(Int.abs(Time.now())) };

  func selfAccount() : ICRC.Account {
    { owner = Principal.fromActor(this); subaccount = null };
  };

  func payoutAccountOf(p : Principal) : ICRC.Account {
    switch (payoutAccounts.get(p)) {
      case (?a) { a };
      case (null) { { owner = p; subaccount = null } };
    };
  };

  func quotaOf(m : Map.Map<Principal, Nat>, p : Principal) : Nat {
    switch (m.get(p)) { case (?n) { n }; case (null) { 0 } };
  };

  func bumpQuota(m : Map.Map<Principal, Nat>, p : Principal, delta : Int) {
    let cur = quotaOf(m, p);
    let next = Int.max(0, cur + delta);
    m.add(p, Int.abs(next));
  };

  func getJobOr(jobId : Types.JobId) : ?Types.Job {
    jobs.get(jobId);
  };

  func newJournalEntry(jobId : Types.JobId, kind : Types.JournalKind, amountE8s : Nat) : Types.JournalEntry {
    let id = nextJournalId;
    nextJournalId += 1;
    let memoText = "sas:" # Nat.toText(jobId) # ":" # Nat.toText(id);
    let entry : Types.JournalEntry = {
      id;
      jobId;
      kind;
      amountE8s;
      createdAtTime = now64();
      memo = memoText.encodeUtf8();
      var state = #pending;
    };
    journal.add(id, entry);
    let jobEntries = switch (journalByJob.get(jobId)) {
      case (?l) { l };
      case (null) { let l = List.empty<Nat>(); journalByJob.add(jobId, l); l };
    };
    jobEntries.add(id);
    entry;
  };

  func entriesOf(jobId : Types.JobId) : [Types.JournalEntry] {
    switch (journalByJob.get(jobId)) {
      case (null) { [] };
      case (?ids) {
        ids.values().filterMap(func(id) { journal.get(id) }).toArray();
      };
    };
  };

  func unresolvedEntryOf(jobId : Types.JobId, isKind : Types.JournalKind -> Bool) : ?Types.JournalEntry {
    entriesOf(jobId).find(
      func(e) {
        isKind(e.kind) and (e.state == #pending or e.state == #unknown);
      }
    );
  };

  /// Ledger call threw. Only a callee-side reject/trap is a KNOWN failure
  /// (ICRC ledgers report business failures as #Err values, so a trap rolled
  /// everything back). Anything else is conservatively #unknown — always
  /// funds-safe here because every retry is idempotent via ledger dedup.
  func isKnownFailure(e : Error.Error) : Bool {
    switch (Error.code(e)) {
      case (#canister_reject or #canister_error or #destination_invalid or #call_error(_)) { true };
      case (_) { false };
    };
  };

  type PullOutcome = {
    #landed : Nat; // block index
    #definitiveFail : Text;
    #stillUnknown;
  };

  /// One idempotent attempt at an inbound pull (deposit or agent bond).
  /// Reuses the entry's created_at_time + memo so the ledger dedups retries.
  func attemptPull(entry : Types.JournalEntry, from : ICRC.Account, ledgerFeeE8s : Nat) : async PullOutcome {
    entry.state := #pending;
    try {
      let res = await (with timeout = LEDGER_TIMEOUT_S) ledger.icrc2_transfer_from({
        spender_subaccount = null;
        from;
        to = selfAccount();
        amount = entry.amountE8s;
        fee = ?ledgerFeeE8s;
        memo = ?entry.memo;
        created_at_time = ?entry.createdAtTime;
      });
      switch (res) {
        case (#Ok(block)) { entry.state := #done({ blockIndex = block }); #landed(block) };
        case (#Err(#Duplicate({ duplicate_of }))) {
          // Original attempt landed; this retry deduped. Success.
          entry.state := #done({ blockIndex = duplicate_of });
          #landed(duplicate_of);
        };
        case (#Err(#InsufficientFunds(_)) or #Err(#InsufficientAllowance(_)) or #Err(#BadFee(_)) or #Err(#BadBurn(_)) or #Err(#TooOld) or #Err(#CreatedInFuture(_))) {
          entry.state := #aborted;
          #definitiveFail("ledger rejected the pull");
        };
        case (#Err(#TemporarilyUnavailable) or #Err(#GenericError(_))) {
          // Could be a lie/transient — funds state uncertain. Idempotent
          // retry via the SAME entry resolves it either way.
          entry.state := #unknown;
          #stillUnknown;
        };
      };
    } catch (e) {
      if (isKnownFailure(e)) {
        entry.state := #aborted;
        #definitiveFail(Error.message(e));
      } else {
        entry.state := #unknown; // includes #system_unknown from bounded wait
        #stillUnknown;
      };
    };
  };

  /// One idempotent attempt at an outbound payout.
  func attemptPayout(entry : Types.JournalEntry, to : ICRC.Account, ledgerFeeE8s : Nat) : async Bool {
    entry.state := #pending;
    try {
      let res = await (with timeout = LEDGER_TIMEOUT_S) ledger.icrc1_transfer({
        from_subaccount = null;
        to;
        // Recipient bears the flat ledger fee (documented in ECONOMICS.md).
        amount = entry.amountE8s - ledgerFeeE8s;
        fee = ?ledgerFeeE8s;
        memo = ?entry.memo;
        created_at_time = ?entry.createdAtTime;
      });
      switch (res) {
        case (#Ok(block)) { entry.state := #done({ blockIndex = block }); true };
        case (#Err(#Duplicate({ duplicate_of }))) {
          entry.state := #done({ blockIndex = duplicate_of });
          true;
        };
        case (#Err(_)) {
          // Payouts spend escrow's own balance: any error leaves the entry
          // retryable. InsufficientFunds here would be an invariant breach —
          // never silently drop an owed payout.
          entry.state := #unknown;
          false;
        };
      };
    } catch (e) {
      entry.state := if (isKnownFailure(e)) { #pending } else { #unknown };
      false;
    };
  };

  func schedulePayout(jobId : Types.JobId, to : ICRC.Account, purpose : Types.PayoutPurpose, amountE8s : Nat, ledgerFeeE8s : Nat) {
    if (amountE8s <= ledgerFeeE8s) {
      // Dust below the ledger fee is unpayable; earmark it, never lose it.
      burnReserveE8s += amountE8s;
      return;
    };
    ignore newJournalEntry(jobId, #payout({ to; purpose }), amountE8s);
  };

  /// Drive all pending payouts for a job; finalize when none remain.
  func drivePayouts(job : Types.Job) : async () {
    for (entry in entriesOf(job.id).values()) {
      switch (entry.kind) {
        case (#payout({ to; purpose = _ })) {
          if (entry.state == #pending or entry.state == #unknown) {
            ignore await attemptPayout(entry, to, job.ledgerFeeE8s);
          };
        };
        case (_) {};
      };
    };
    switch (
      unresolvedEntryOf(
        job.id,
        func(k) { switch (k) { case (#payout(_)) { true }; case (_) { false } } },
      )
    ) {
      case (null) { finalize(job) };
      case (?_) {};
    };
  };

  func finalize(job : Types.Job) {
    switch (job.status) {
      case (#releasing) {
        let agent = switch (job.agent) {
          case (?a) { a };
          case (null) { return }; // unreachable: releasing implies agent
        };
        let split = Fees.split(job.grossE8s, FEE_BPS, BURN_SHARE_PCT);
        burnReserveE8s += split.burnPathE8s;
        treasuryReserveE8s += split.treasuryE8s;
        let receipt : Types.Receipt = {
          schemaVersion = 1;
          jobId = job.id;
          agent;
          client = job.client;
          token = job.token;
          grossE8s = split.grossE8s;
          feeE8s = split.feeE8s;
          burnOrEarmarkE8s = split.burnPathE8s;
          treasuryE8s = split.treasuryE8s;
          netE8s = split.agentNetE8s;
          ts = nowNs();
          decisionHash = null;
        };
        receipts.add(job.id, receipt);
        let agentReceipts = switch (receiptsByAgent.get(agent)) {
          case (?l) { l };
          case (null) { let l = List.empty<Types.JobId>(); receiptsByAgent.add(agent, l); l };
        };
        agentReceipts.add(job.id);
        job.status := #released;
        onTerminal(job);
      };
      case (#refunding) {
        job.status := #refunded;
        onTerminal(job);
      };
      case (_) {};
    };
  };

  func onTerminal(job : Types.Job) {
    bumpQuota(openJobsPerClient, job.client, -1);
    switch (bids.get(job.id)) {
      case (?bidders) {
        for (b in bidders.values()) { bumpQuota(openBidsPerAgent, b, -1) };
        ignore bids.remove(job.id);
      };
      case (null) {};
    };
  };

  func beginRelease(job : Types.Job) : async () {
    let agent = switch (job.agent) {
      case (?a) { a };
      case (null) { return };
    };
    job.status := #releasing;
    let split = Fees.split(job.grossE8s, FEE_BPS, BURN_SHARE_PCT);
    schedulePayout(job.id, payoutAccountOf(agent), #agentNet, split.agentNetE8s, job.ledgerFeeE8s);
    schedulePayout(job.id, { owner = agent; subaccount = null }, #agentBondRefund, job.agentBondE8s, job.ledgerFeeE8s);
    schedulePayout(job.id, { owner = job.client; subaccount = null }, #clientBondRefund, job.clientBondE8s, job.ledgerFeeE8s);
    await drivePayouts(job);
  };

  func beginRefund(job : Types.Job, refundAgentBond : Bool) : async () {
    job.status := #refunding;
    schedulePayout(
      job.id,
      { owner = job.client; subaccount = null },
      #clientGrossRefund,
      job.grossE8s + job.clientBondE8s,
      job.ledgerFeeE8s,
    );
    if (refundAgentBond and job.agentBondE8s > 0) {
      switch (job.agent) {
        case (?a) {
          schedulePayout(job.id, { owner = a; subaccount = null }, #agentBondRefund, job.agentBondE8s, job.ledgerFeeE8s);
        };
        case (null) {};
      };
    };
    await drivePayouts(job);
  };

  // ---------- public API: updates ----------

  public shared ({ caller }) func createJob(
    specHash : Blob,
    token : Types.Token,
    grossE8s : Nat,
    deadlineNs : Int,
    skills : [Text],
  ) : async Types.Result<Types.JobId> {
    switch (Validate.requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    switch (Validate.checkSpecHash(specHash)) { case (?e) { return #err(e) }; case (null) {} };
    switch (Validate.checkSkills(skills)) { case (?e) { return #err(e) }; case (null) {} };
    if (grossE8s < MIN_JOB_GROSS_E8S) {
      return #err(#invalidInput("gross below constitutional minimum"));
    };
    if (grossE8s > cfg.opCapE8s) {
      return #err(#invalidInput("gross above operational cap"));
    };
    if (deadlineNs < nowNs() + cfg.minDeadlineNs) {
      return #err(#invalidInput("deadline too soon"));
    };
    if (quotaOf(openJobsPerClient, caller) >= MAX_OPEN_JOBS_PER_CLIENT) {
      return #err(#quotaExceeded("too many open jobs"));
    };

    let lockKey = "create:" # caller.toText();
    if (not Guard.acquire(locks, lockKey)) { return #err(#locked) };
    try {
      // Ledger fee fetched live, never hardcoded (handoff §5).
      let ledgerFeeE8s = await (with timeout = LEDGER_TIMEOUT_S) ledger.icrc1_fee();

      let jobId = nextJobId;
      nextJobId += 1;
      let job : Types.Job = {
        id = jobId;
        client = caller;
        specHash;
        token;
        grossE8s;
        clientBondE8s = CLIENT_JOB_BOND_E8S;
        ledgerFeeE8s;
        deadlineNs;
        skills;
        createdAtNs = nowNs();
        var status = #depositPending;
        var selectedAgent = null;
        var agent = null;
        var agentBondE8s = 0;
        var deliveredAtNs = null;
        var payloadHash = null;
        var depositBlockIndex = null;
      };
      jobs.add(jobId, job);
      bumpQuota(openJobsPerClient, caller, 1);

      // Journal BEFORE the await.
      let entry = newJournalEntry(jobId, #deposit, grossE8s + CLIENT_JOB_BOND_E8S);
      switch (await attemptPull(entry, { owner = caller; subaccount = null }, ledgerFeeE8s)) {
        case (#landed(block)) {
          if (processedDepositBlocks.contains(block)) {
            // Same ledger block credited twice — impossible unless the ledger
            // misbehaves. Fail closed on the new job; funds recoverable via
            // reconcileDeposit after investigation.
            return #err(#ledgerError("duplicate deposit block index"));
          };
          processedDepositBlocks.add(block);
          job.depositBlockIndex := ?block;
          job.status := #open;
          #ok(jobId);
        };
        case (#definitiveFail(msg)) {
          job.status := #aborted;
          bumpQuota(openJobsPerClient, caller, -1);
          #err(#ledgerError(msg));
        };
        case (#stillUnknown) {
          // Funds state uncertain; job stays #depositPending. Client (or
          // anyone) drives resolution via reconcileDeposit.
          #err(#depositUnresolved);
        };
      };
    } finally {
      Guard.release(locks, lockKey);
    };
  };

  public shared ({ caller }) func reconcileDeposit(jobId : Types.JobId) : async Types.Result<Types.JobId> {
    switch (Validate.requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    let job = switch (getJobOr(jobId)) { case (?j) { j }; case (null) { return #err(#notFound) } };
    if (job.status != #depositPending) { return #err(#wrongStatus({ current = job.status })) };
    let entry = switch (
      unresolvedEntryOf(jobId, func(k) { k == #deposit })
    ) {
      case (?e) { e };
      case (null) { return #err(#notFound) };
    };
    let lockKey = "job:" # Nat.toText(jobId);
    if (not Guard.acquire(locks, lockKey)) { return #err(#locked) };
    try {
      switch (await attemptPull(entry, { owner = job.client; subaccount = null }, job.ledgerFeeE8s)) {
        case (#landed(block)) {
          if (not processedDepositBlocks.contains(block)) {
            processedDepositBlocks.add(block);
          };
          job.depositBlockIndex := ?block;
          job.status := #open;
          #ok(jobId);
        };
        case (#definitiveFail(msg)) {
          job.status := #aborted;
          bumpQuota(openJobsPerClient, job.client, -1);
          #err(#ledgerError(msg));
        };
        case (#stillUnknown) { #err(#depositUnresolved) };
      };
    } finally {
      Guard.release(locks, lockKey);
    };
  };

  public shared ({ caller }) func bid(jobId : Types.JobId) : async Types.Result<()> {
    switch (Validate.requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    let job = switch (getJobOr(jobId)) { case (?j) { j }; case (null) { return #err(#notFound) } };
    if (job.status != #open) { return #err(#wrongStatus({ current = job.status })) };
    if (not Lifecycle.beforeDeadline(nowNs(), job.deadlineNs)) { return #err(#invalidInput("job past deadline")) };
    if (caller == job.client) { return #err(#invalidInput("client cannot bid on own job")) };
    if (quotaOf(openBidsPerAgent, caller) >= MAX_OPEN_BIDS_PER_AGENT) {
      return #err(#quotaExceeded("too many open bids"));
    };
    let jobBids = switch (bids.get(jobId)) {
      case (?l) { l };
      case (null) { let l = List.empty<Principal>(); bids.add(jobId, l); l };
    };
    if (jobBids.size() >= MAX_BIDS_PER_JOB) { return #err(#quotaExceeded("bid list full")) };
    if (jobBids.contains(caller)) { return #err(#invalidInput("already bid")) };
    jobBids.add(caller);
    bumpQuota(openBidsPerAgent, caller, 1);
    #ok(());
  };

  public shared ({ caller }) func selectBid(jobId : Types.JobId, agent : Principal) : async Types.Result<()> {
    switch (Validate.requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    let job = switch (getJobOr(jobId)) { case (?j) { j }; case (null) { return #err(#notFound) } };
    if (caller != job.client) { return #err(#notAuthorized) };
    if (job.status != #open) { return #err(#wrongStatus({ current = job.status })) };
    let hasBid = switch (bids.get(jobId)) {
      case (?l) { l.contains(agent) };
      case (null) { false };
    };
    if (not hasBid) { return #err(#invalidInput("that principal has not bid")) };
    // A different selectee's bond pull might be unresolved; settle it first.
    switch (
      unresolvedEntryOf(jobId, func(k) { switch (k) { case (#agentBond(_)) { true }; case (_) { false } } })
    ) {
      case (?_) { return #err(#depositUnresolved) };
      case (null) {};
    };
    job.selectedAgent := ?agent;
    #ok(());
  };

  public shared ({ caller }) func acceptJob(jobId : Types.JobId) : async Types.Result<()> {
    switch (Validate.requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    let job = switch (getJobOr(jobId)) { case (?j) { j }; case (null) { return #err(#notFound) } };
    if (job.status != #open) { return #err(#wrongStatus({ current = job.status })) };
    if (job.selectedAgent != ?caller) { return #err(#notAuthorized) };
    if (not Lifecycle.beforeDeadline(nowNs(), job.deadlineNs)) { return #err(#invalidInput("job past deadline")) };

    let lockKey = "job:" # Nat.toText(jobId);
    if (not Guard.acquire(locks, lockKey)) { return #err(#locked) };
    try {
      // Reuse an unresolved bond entry for this agent (idempotent retry);
      // otherwise journal a fresh one BEFORE the await.
      let entry = switch (
        unresolvedEntryOf(jobId, func(k) { k == #agentBond({ agent = caller }) })
      ) {
        case (?e) { e };
        case (null) { newJournalEntry(jobId, #agentBond({ agent = caller }), AGENT_JOB_BOND_E8S) };
      };
      switch (await attemptPull(entry, { owner = caller; subaccount = null }, job.ledgerFeeE8s)) {
        case (#landed(_)) {
          job.agent := ?caller;
          job.agentBondE8s := AGENT_JOB_BOND_E8S;
          job.status := #assigned;
          #ok(());
        };
        case (#definitiveFail(msg)) { #err(#ledgerError(msg)) };
        case (#stillUnknown) { #err(#depositUnresolved) };
      };
    } finally {
      Guard.release(locks, lockKey);
    };
  };

  /// Settle an unresolved agent-bond pull when the agent isn't retrying
  /// acceptJob themselves (e.g. the job expired meanwhile). If the bond
  /// landed but the job can no longer be assigned, the bond is refunded.
  public shared ({ caller }) func resolveAgentBond(jobId : Types.JobId) : async Types.Result<()> {
    switch (Validate.requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    let job = switch (getJobOr(jobId)) { case (?j) { j }; case (null) { return #err(#notFound) } };
    let entry = switch (
      unresolvedEntryOf(jobId, func(k) { switch (k) { case (#agentBond(_)) { true }; case (_) { false } } })
    ) {
      case (?e) { e };
      case (null) { return #err(#notFound) };
    };
    let bondAgent = switch (entry.kind) {
      case (#agentBond({ agent })) { agent };
      case (_) { return #err(#notFound) };
    };
    let lockKey = "job:" # Nat.toText(jobId);
    if (not Guard.acquire(locks, lockKey)) { return #err(#locked) };
    try {
      switch (await attemptPull(entry, { owner = bondAgent; subaccount = null }, job.ledgerFeeE8s)) {
        case (#landed(_)) {
          if (job.status == #open and job.selectedAgent == ?bondAgent and Lifecycle.beforeDeadline(nowNs(), job.deadlineNs)) {
            job.agent := ?bondAgent;
            job.agentBondE8s := AGENT_JOB_BOND_E8S;
            job.status := #assigned;
          } else {
            // Bond landed but assignment is no longer possible: refund it.
            schedulePayout(jobId, { owner = bondAgent; subaccount = null }, #agentBondRefund, AGENT_JOB_BOND_E8S, job.ledgerFeeE8s);
            await drivePayouts(job);
          };
          #ok(());
        };
        case (#definitiveFail(_)) {
          if (job.selectedAgent == ?bondAgent) { job.selectedAgent := null };
          #ok(());
        };
        case (#stillUnknown) { #err(#depositUnresolved) };
      };
    } finally {
      Guard.release(locks, lockKey);
    };
  };

  public shared ({ caller }) func deliver(jobId : Types.JobId, payloadHash : Blob) : async Types.Result<()> {
    switch (Validate.requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    switch (Validate.checkPayloadHash(payloadHash)) { case (?e) { return #err(e) }; case (null) {} };
    let job = switch (getJobOr(jobId)) { case (?j) { j }; case (null) { return #err(#notFound) } };
    if (job.status != #assigned) { return #err(#wrongStatus({ current = job.status })) };
    if (job.agent != ?caller) { return #err(#notAuthorized) };
    if (not Lifecycle.beforeDeadline(nowNs(), job.deadlineNs)) { return #err(#invalidInput("job past deadline")) };
    job.payloadHash := ?payloadHash;
    job.deliveredAtNs := ?nowNs();
    job.status := #delivered;
    #ok(());
  };

  public shared ({ caller }) func acceptDelivery(jobId : Types.JobId) : async Types.Result<()> {
    switch (Validate.requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    let job = switch (getJobOr(jobId)) { case (?j) { j }; case (null) { return #err(#notFound) } };
    if (caller != job.client) { return #err(#notAuthorized) };
    if (job.status != #delivered) { return #err(#wrongStatus({ current = job.status })) };
    let lockKey = "job:" # Nat.toText(jobId);
    if (not Guard.acquire(locks, lockKey)) { return #err(#locked) };
    try {
      await beginRelease(job);
      #ok(());
    } finally {
      Guard.release(locks, lockKey);
    };
  };

  /// Time-based transitions; any authenticated principal may drive them —
  /// funds only ever move to their rightful owners.
  public shared ({ caller }) func timeoutJob(jobId : Types.JobId) : async Types.Result<()> {
    switch (Validate.requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    let job = switch (getJobOr(jobId)) { case (?j) { j }; case (null) { return #err(#notFound) } };
    // An unresolved agent-bond pull must be settled first so no bond can be
    // stranded by a refund racing it.
    switch (
      unresolvedEntryOf(jobId, func(k) { switch (k) { case (#agentBond(_)) { true }; case (_) { false } } })
    ) {
      case (?_) { return #err(#depositUnresolved) };
      case (null) {};
    };
    let lockKey = "job:" # Nat.toText(jobId);
    if (not Guard.acquire(locks, lockKey)) { return #err(#locked) };
    try {
      switch (Lifecycle.timeoutAction(job.status, nowNs(), job.deadlineNs, job.deliveredAtNs, cfg.reviewWindowNs)) {
        case (#refundOpen) {
          await beginRefund(job, false);
          #ok(());
        };
        case (#refundAssigned) {
          // TODO OPEN QUESTION: no agent-bond slash in Phase 1 (never invent
          // penalties); dispute-era rules land in Phase 3.
          await beginRefund(job, true);
          #ok(());
        };
        case (#releaseDelivered) {
          // Client silent past the review window: delivered work gets paid.
          await beginRelease(job);
          #ok(());
        };
        case (#drivePayouts) {
          await drivePayouts(job);
          #ok(());
        };
        case (#tooEarly) { #err(#invalidInput("not yet timed out")) };
        case (#wrongStatus) { #err(#wrongStatus({ current = job.status })) };
      };
    } finally {
      Guard.release(locks, lockKey);
    };
  };

  public shared ({ caller }) func cancelJob(jobId : Types.JobId) : async Types.Result<()> {
    switch (Validate.requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    let job = switch (getJobOr(jobId)) { case (?j) { j }; case (null) { return #err(#notFound) } };
    if (caller != job.client) { return #err(#notAuthorized) };
    if (job.status != #open) { return #err(#wrongStatus({ current = job.status })) };
    switch (
      unresolvedEntryOf(jobId, func(k) { switch (k) { case (#agentBond(_)) { true }; case (_) { false } } })
    ) {
      case (?_) { return #err(#depositUnresolved) };
      case (null) {};
    };
    let lockKey = "job:" # Nat.toText(jobId);
    if (not Guard.acquire(locks, lockKey)) { return #err(#locked) };
    try {
      await beginRefund(job, false);
      #ok(());
    } finally {
      Guard.release(locks, lockKey);
    };
  };

  /// Retry stuck payouts for a job in #releasing/#refunding. Idempotent;
  /// anyone authenticated may drive it. Funds can never be stranded.
  public shared ({ caller }) func processPayouts(jobId : Types.JobId) : async Types.Result<()> {
    switch (Validate.requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    let job = switch (getJobOr(jobId)) { case (?j) { j }; case (null) { return #err(#notFound) } };
    if (job.status != #releasing and job.status != #refunding) {
      return #err(#wrongStatus({ current = job.status }));
    };
    let lockKey = "job:" # Nat.toText(jobId);
    if (not Guard.acquire(locks, lockKey)) { return #err(#locked) };
    try {
      await drivePayouts(job);
      #ok(());
    } finally {
      Guard.release(locks, lockKey);
    };
  };

  public shared ({ caller }) func setPayoutAccount(account : ICRC.Account) : async Types.Result<()> {
    switch (Validate.requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    switch (account.subaccount) {
      case (?sub) {
        if (sub.size() != 32) { return #err(#invalidInput("subaccount must be 32 bytes")) };
      };
      case (null) {};
    };
    if (Principal.isAnonymous(account.owner)) {
      return #err(#invalidInput("payout account cannot be anonymous"));
    };
    payoutAccounts.add(caller, account);
    #ok(());
  };

  // ---------- public API: queries ----------

  public query func version() : async Text {
    "square_escrow 0.1.0 (phase 1: escrow spine, local)";
  };

  public query func previewSplit(grossE8s : Nat) : async Types.FeeSplit {
    Fees.split(grossE8s, FEE_BPS, BURN_SHARE_PCT);
  };

  func viewOf(job : Types.Job) : Types.JobView {
    {
      id = job.id;
      client = job.client;
      specHash = job.specHash;
      token = job.token;
      grossE8s = job.grossE8s;
      clientBondE8s = job.clientBondE8s;
      ledgerFeeE8s = job.ledgerFeeE8s;
      deadlineNs = job.deadlineNs;
      skills = job.skills;
      createdAtNs = job.createdAtNs;
      status = job.status;
      selectedAgent = job.selectedAgent;
      agent = job.agent;
      agentBondE8s = job.agentBondE8s;
      deliveredAtNs = job.deliveredAtNs;
      payloadHash = job.payloadHash;
      depositBlockIndex = job.depositBlockIndex;
    };
  };

  public query func getJob(jobId : Types.JobId) : async ?Types.JobView {
    switch (jobs.get(jobId)) { case (?j) { ?viewOf(j) }; case (null) { null } };
  };

  public query func listOpenJobs(offset : Nat, limit : Nat) : async [Types.JobView] {
    let bounded = Nat.min(limit, 50);
    jobs.values()
      .filter(func(j) { j.status == #open })
      .drop(offset)
      .take(bounded)
      .map(viewOf)
      .toArray();
  };

  public query func getReceipt(jobId : Types.JobId) : async ?Types.Receipt {
    receipts.get(jobId);
  };

  public query func getReceiptsForAgent(agent : Principal) : async [Types.Receipt] {
    switch (receiptsByAgent.get(agent)) {
      case (null) { [] };
      case (?ids) {
        ids.values().filterMap(func(id) { receipts.get(id) }).toArray();
      };
    };
  };

  /// Reputation = receipts ONLY (v1). The lobby canister reads this.
  public query func getAgentStats(agent : Principal) : async Types.AgentStats {
    var completedJobs = 0;
    var grossEarnedE8s = 0;
    var netEarnedE8s = 0;
    var firstTs : ?Int = null;
    var lastTs : ?Int = null;
    switch (receiptsByAgent.get(agent)) {
      case (null) {};
      case (?ids) {
        for (id in ids.values()) {
          switch (receipts.get(id)) {
            case (?r) {
              completedJobs += 1;
              grossEarnedE8s += r.grossE8s;
              netEarnedE8s += r.netE8s;
              firstTs := switch (firstTs) { case (null) { ?r.ts }; case (?f) { ?Int.min(f, r.ts) } };
              lastTs := switch (lastTs) { case (null) { ?r.ts }; case (?l) { ?Int.max(l, r.ts) } };
            };
            case (null) {};
          };
        };
      };
    };
    { completedJobs; grossEarnedE8s; netEarnedE8s; firstReceiptTs = firstTs; lastReceiptTs = lastTs };
  };

  public query func getJournal(jobId : Types.JobId) : async [Types.JournalEntryView] {
    entriesOf(jobId).map(
      func(e) {
        {
          id = e.id;
          jobId = e.jobId;
          kind = e.kind;
          amountE8s = e.amountE8s;
          createdAtTime = e.createdAtTime;
          memo = e.memo;
          state = e.state;
        };
      }
    );
  };

  public query func getEscrowInfo() : async {
    ledgerId : Principal;
    opCapE8s : Nat;
    minJobGrossE8s : Nat;
    clientJobBondE8s : Nat;
    agentJobBondE8s : Nat;
    feeBps : Nat;
    burnSharePct : Nat;
    burnReserveE8s : Nat;
    treasuryReserveE8s : Nat;
  } {
    {
      ledgerId = cfg.ledgerId;
      opCapE8s = cfg.opCapE8s;
      minJobGrossE8s = MIN_JOB_GROSS_E8S;
      clientJobBondE8s = CLIENT_JOB_BOND_E8S;
      agentJobBondE8s = AGENT_JOB_BOND_E8S;
      feeBps = FEE_BPS;
      burnSharePct = BURN_SHARE_PCT;
      burnReserveE8s;
      treasuryReserveE8s;
    };
  };
};

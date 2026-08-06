import Blob "mo:core/Blob";
import Map "mo:core/Map";
import Nat "mo:core/Nat";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import ICRC "../shared/ICRC";

/// ============================ TEST ONLY ====================================
/// Dummy ICRC-1/ICRC-2 ledger for LOCAL testing of square_escrow (handoff §5,
/// "test against a locally deployed ICRC-1 dummy ledger").
///
/// NEVER deploy to mainnet. Not part of the product. Fail modes exist purely
/// so tests can exercise the escrow's compensation paths.
/// ===========================================================================
persistent actor class TestLedger(
  init : {
    initialBalances : [(ICRC.Account, Nat)];
    fee : Nat;
  }
) {

  type FailMode = {
    #none;
    // Reject the next icrc2_transfer_from WITHOUT moving funds (transient-style).
    #rejectTransferFromOnce;
    // Move funds for the next icrc2_transfer_from but still return an error —
    // simulates "ambiguous outcome: the operation landed but the caller can't
    // know". The escrow must recover via idempotent retry + dedup.
    #pullThenErrorOnce;
    // Reject the next icrc1_transfer without moving funds.
    #rejectTransferOnce;
  };

  var failMode : FailMode = #none;

  let balances = Map.empty<Text, Nat>();
  // allowance key: fromAccount|spenderAccount
  let allowances = Map.empty<Text, Nat>();
  // dedup key -> block index of the original transaction
  let dedup = Map.empty<Text, Nat>();
  var nextBlock : Nat = 0;
  let transferFee : Nat = init.fee;

  func accountKey(a : ICRC.Account) : Text {
    let sub = switch (a.subaccount) {
      case (null) { "default" };
      case (?b) {
        if (b.size() == 0) { "default" } else { debug_show (b) };
      };
    };
    a.owner.toText() # "/" # sub;
  };

  func balanceOf(key : Text) : Nat {
    switch (balances.get(key)) { case (?b) { b }; case (null) { 0 } };
  };

  func credit(key : Text, amount : Nat) {
    balances.add(key, balanceOf(key) + amount);
  };

  func debit(key : Text, amount : Nat) {
    // Callers must check funds first; underflow here is a test-ledger bug.
    balances.add(key, balanceOf(key) - amount);
  };

  func dedupKey(kind : Text, from : Text, to : Text, amount : Nat, createdAt : ?Nat64, memo : ?Blob) : ?Text {
    // Per ICRC-1, dedup applies only when created_at_time is set.
    switch (createdAt) {
      case (null) { null };
      case (?t) {
        ?(kind # "|" # from # "|" # to # "|" # amount.toText() # "|"
        # debug_show (t) # "|" # debug_show (memo));
      };
    };
  };

  // Seed initial balances (persistent field: initializer runs once at
  // install, never on upgrade — transient would dangerously re-seed).
  let _seeded : Bool = do {
    for ((account, amount) in init.initialBalances.values()) {
      credit(accountKey(account), amount);
    };
    true;
  };

  public func setFailMode(mode : FailMode) : async () {
    failMode := mode;
  };

  public query func icrc1_fee() : async Nat {
    transferFee;
  };

  public query func icrc1_balance_of(account : ICRC.Account) : async Nat {
    balanceOf(accountKey(account));
  };

  public query func icrc2_allowance(args : ICRC.AllowanceArgs) : async ICRC.Allowance {
    let key = accountKey(args.account) # "|" # accountKey(args.spender);
    switch (allowances.get(key)) {
      case (?a) { { allowance = a; expires_at = null } };
      case (null) { { allowance = 0; expires_at = null } };
    };
  };

  public shared ({ caller }) func icrc2_approve(args : ICRC.ApproveArg) : async { #Ok : Nat; #Err : ICRC.ApproveError } {
    let from = { owner = caller; subaccount = args.from_subaccount };
    let fromKey = accountKey(from);
    switch (args.fee) {
      case (?f) { if (f != transferFee) { return #Err(#BadFee({ expected_fee = transferFee })) } };
      case (null) {};
    };
    if (balanceOf(fromKey) < transferFee) {
      return #Err(#InsufficientFunds({ balance = balanceOf(fromKey) }));
    };
    debit(fromKey, transferFee);
    let key = fromKey # "|" # accountKey(args.spender);
    allowances.add(key, args.amount);
    nextBlock += 1;
    #Ok(nextBlock - 1);
  };

  public shared ({ caller }) func icrc2_transfer_from(args : ICRC.TransferFromArg) : async { #Ok : Nat; #Err : ICRC.TransferFromError } {
    let spender = { owner = caller; subaccount = args.spender_subaccount };
    let fromKey = accountKey(args.from);
    let toKey = accountKey(args.to);
    let allowKey = fromKey # "|" # accountKey(spender);

    switch (args.fee) {
      case (?f) { if (f != transferFee) { return #Err(#BadFee({ expected_fee = transferFee })) } };
      case (null) {};
    };

    // Dedup BEFORE fail modes: an idempotent retry of a landed transfer must
    // report the original block, exactly like the real ledger.
    let dkey = dedupKey("xfrom" # allowKey, fromKey, toKey, args.amount, args.created_at_time, args.memo);
    switch (dkey) {
      case (?k) {
        switch (dedup.get(k)) {
          case (?original) { return #Err(#Duplicate({ duplicate_of = original })) };
          case (null) {};
        };
      };
      case (null) {};
    };

    if (failMode == #rejectTransferFromOnce) {
      failMode := #none;
      return #Err(#TemporarilyUnavailable);
    };

    let allowance = switch (allowances.get(allowKey)) { case (?a) { a }; case (null) { 0 } };
    let total = args.amount + transferFee;
    if (allowance < total) {
      return #Err(#InsufficientAllowance({ allowance }));
    };
    if (balanceOf(fromKey) < total) {
      return #Err(#InsufficientFunds({ balance = balanceOf(fromKey) }));
    };

    debit(fromKey, total);
    credit(toKey, args.amount);
    allowances.add(allowKey, allowance - total);
    let block = nextBlock;
    nextBlock += 1;
    switch (dkey) { case (?k) { dedup.add(k, block) }; case (null) {} };

    if (failMode == #pullThenErrorOnce) {
      failMode := #none;
      // Funds moved and the block exists, but the caller sees an error.
      return #Err(#GenericError({ error_code = 999; message = "TEST: ambiguous outcome" }));
    };

    #Ok(block);
  };

  public shared ({ caller }) func icrc1_transfer(args : ICRC.TransferArg) : async { #Ok : Nat; #Err : ICRC.TransferError } {
    let from = { owner = caller; subaccount = args.from_subaccount };
    let fromKey = accountKey(from);
    let toKey = accountKey(args.to);

    switch (args.fee) {
      case (?f) { if (f != transferFee) { return #Err(#BadFee({ expected_fee = transferFee })) } };
      case (null) {};
    };

    let dkey = dedupKey("xfer" # fromKey, fromKey, toKey, args.amount, args.created_at_time, args.memo);
    switch (dkey) {
      case (?k) {
        switch (dedup.get(k)) {
          case (?original) { return #Err(#Duplicate({ duplicate_of = original })) };
          case (null) {};
        };
      };
      case (null) {};
    };

    if (failMode == #rejectTransferOnce) {
      failMode := #none;
      return #Err(#TemporarilyUnavailable);
    };

    let total = args.amount + transferFee;
    if (balanceOf(fromKey) < total) {
      return #Err(#InsufficientFunds({ balance = balanceOf(fromKey) }));
    };

    debit(fromKey, total);
    credit(toKey, args.amount);
    let block = nextBlock;
    nextBlock += 1;
    switch (dkey) { case (?k) { dedup.add(k, block) }; case (null) {} };
    #Ok(block);
  };
};

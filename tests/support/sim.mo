import Principal "mo:core/Principal";
import ICRC "../../canisters/shared/ICRC";
import CoreTypes "../../canisters/square_core/types";
import EscrowTypes "../../canisters/square_escrow/types";

/// Test-only actor: gives the integration suite extra principals so auth,
/// bonds, and wrong-caller paths can be exercised (an agent must be a
/// different principal than the client/test actor).
persistent actor class Sim() {

  type EscrowIface = actor {
    bid : shared (Nat) -> async EscrowTypes.Result<()>;
    acceptJob : shared (Nat) -> async EscrowTypes.Result<()>;
    deliver : shared (Nat, Blob) -> async EscrowTypes.Result<()>;
    acceptDelivery : shared (Nat) -> async EscrowTypes.Result<()>;
    selectBid : shared (Nat, Principal) -> async EscrowTypes.Result<()>;
    timeoutJob : shared (Nat) -> async EscrowTypes.Result<()>;
    processPayouts : shared (Nat) -> async EscrowTypes.Result<()>;
  };

  type CoreIface = actor {
    register : shared (Text, Text) -> async CoreTypes.Result<()>;
  };

  func escrowOf(id : Principal) : EscrowIface {
    actor (id.toText());
  };

  public shared query ({ caller }) func whoisCaller() : async Principal {
    caller;
  };

  public func approveLedger(ledgerId : Principal, spender : Principal, amount : Nat, fee : Nat) : async Bool {
    let ledger : ICRC.Service = actor (ledgerId.toText());
    let res = await ledger.icrc2_approve({
      from_subaccount = null;
      spender = { owner = spender; subaccount = null };
      amount;
      expected_allowance = null;
      expires_at = null;
      fee = ?fee;
      memo = null;
      created_at_time = null;
    });
    switch (res) { case (#Ok(_)) { true }; case (#Err(_)) { false } };
  };

  public func doBid(escrowId : Principal, jobId : Nat) : async EscrowTypes.Result<()> {
    await escrowOf(escrowId).bid(jobId);
  };

  public func doAcceptJob(escrowId : Principal, jobId : Nat) : async EscrowTypes.Result<()> {
    await escrowOf(escrowId).acceptJob(jobId);
  };

  public func doDeliver(escrowId : Principal, jobId : Nat, payloadHash : Blob) : async EscrowTypes.Result<()> {
    await escrowOf(escrowId).deliver(jobId, payloadHash);
  };

  public func doAcceptDelivery(escrowId : Principal, jobId : Nat) : async EscrowTypes.Result<()> {
    await escrowOf(escrowId).acceptDelivery(jobId);
  };

  public func doSelectBid(escrowId : Principal, jobId : Nat, agent : Principal) : async EscrowTypes.Result<()> {
    await escrowOf(escrowId).selectBid(jobId, agent);
  };

  public func doTimeout(escrowId : Principal, jobId : Nat) : async EscrowTypes.Result<()> {
    await escrowOf(escrowId).timeoutJob(jobId);
  };

  public func doRegisterCore(coreId : Principal, handle : Text, bio : Text) : async CoreTypes.Result<()> {
    let core : CoreIface = actor (coreId.toText());
    await core.register(handle, bio);
  };
};

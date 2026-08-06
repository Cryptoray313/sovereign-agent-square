import Fees "lib/Fees";
import Types "types";

/// square_escrow — THE SPINE (handoff §4).
///
/// Phase 0: skeleton only. Phase 1 lands the escrow flow against a local dummy
/// ICRC-1 ledger: createJob -> deposit (ICRC-2 approve/transferFrom) ->
/// deliver -> accept/timeout -> release (95/3/2) -> receipt.
///
/// Standing invariants for every phase (handoff §4.2):
/// - Escrow never imports or calls square_core. Core reads receipts via query.
/// - Journal state BEFORE every await; compensate on failure; #Unknown on
///   ambiguous ledger errors.
/// - Per-job CallerGuard lock released in `finally`.
/// - Reject the anonymous principal on every authenticated endpoint; bound all
///   input sizes.
/// - Bounded-wait inter-canister calls only.
/// - Block-index dedup on deposits.
/// - Per-agent storage quotas + bonds.
/// - No secrets in canister memory, ever.
/// - Freezing threshold 90 days (set at deploy; funds-holding canister).
persistent actor SquareEscrow {

  public query func version() : async Text {
    "square_escrow 0.0.1 (phase 0 skeleton)";
  };

  /// Preview the L11 fee split for a gross amount at current default rates.
  /// Deterministic-cost guarantee: an agent knows its exact net before it bids.
  /// Phase 3 reads fee_bps/burn_share live from the constitution canister;
  /// until then the L11 defaults are compiled in.
  public query func previewSplit(grossE8s : Nat) : async Types.FeeSplit {
    Fees.split(grossE8s, 500, 60);
  };
};

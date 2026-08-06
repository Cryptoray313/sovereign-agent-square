import Types "../types";

/// Pure time/state decisions for the escrow lifecycle — the single source of
/// truth for deadline and review-window semantics. Kept pure (explicit `now`)
/// so every boundary is property-testable without a replica.
///
/// Semantics:
/// - `deadline` is deliver-BY, inclusive: bids/accepts/delivers are allowed
///   while now <= deadline; expiry timeouts become eligible when now > deadline.
/// - The review window is a minimum wait: release-by-timeout becomes eligible
///   when now >= deliveredAt + reviewWindow.
module {
  public type TimeoutAction = {
    #refundOpen; // expired with no agent bound: refund client
    #refundAssigned; // expired without delivery: refund client, return agent bond
    #releaseDelivered; // client silent past review window: pay the agent
    #drivePayouts; // already settling: retry stuck payouts
    #tooEarly;
    #wrongStatus;
  };

  public func beforeDeadline(nowNs : Int, deadlineNs : Int) : Bool {
    nowNs <= deadlineNs;
  };

  public func timeoutAction(
    status : Types.JobStatus,
    nowNs : Int,
    deadlineNs : Int,
    deliveredAtNs : ?Int,
    reviewWindowNs : Nat,
  ) : TimeoutAction {
    switch (status) {
      case (#open) {
        if (nowNs > deadlineNs) { #refundOpen } else { #tooEarly };
      };
      case (#assigned) {
        if (nowNs > deadlineNs) { #refundAssigned } else { #tooEarly };
      };
      case (#delivered) {
        let deliveredAt = switch (deliveredAtNs) { case (?t) { t }; case (null) { 0 } };
        if (nowNs >= deliveredAt + reviewWindowNs) { #releaseDelivered } else { #tooEarly };
      };
      case (#releasing or #refunding) { #drivePayouts };
      case (_) { #wrongStatus };
    };
  };
};

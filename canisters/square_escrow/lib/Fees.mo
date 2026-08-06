import Types "../types";

/// L11 fee math — pure functions only, no state, no awaits.
///
/// Canonical (handoff §5):
///   fee       = gross * fee_bps / 10_000        (default 500 bps = 5%)
///   agent_net = gross - fee                      (95%)
///   treasury  = fee * (100 - burn_share) / 100   (40% of fee = 2% of gross)
///   burn_path = fee - treasury                   (60% of fee = 3% of gross)
///
/// Integer division remainders inside the fee split land in burn_path — never
/// treasury, never lost (L11). PROPERTY: agentNet + burnPath + treasury ==
/// gross, exactly, always.
///
/// Rounding rule (CONFIRMED by EZ 2026-08-06, frozen in tests/fees.test.mo):
/// the fee is floored — agent-favoring at the fee boundary. Any e8s remainder
/// of gross*bps/10_000 stays with the agent.
module {
  public let FEE_BPS_DENOMINATOR : Nat = 10_000;

  public func split(grossE8s : Nat, feeBps : Nat, burnSharePct : Nat) : Types.FeeSplit {
    assert feeBps <= FEE_BPS_DENOMINATOR;
    assert burnSharePct <= 100;
    let feeE8s = grossE8s * feeBps / FEE_BPS_DENOMINATOR;
    let agentNetE8s = grossE8s - feeE8s;
    // Floor treasury so every remainder e8s lands in the burn path.
    let treasuryE8s = feeE8s * (100 - burnSharePct) / 100;
    let burnPathE8s = feeE8s - treasuryE8s;
    {
      grossE8s;
      feeE8s;
      agentNetE8s;
      burnPathE8s;
      treasuryE8s;
    };
  };

  /// The conservation invariant, exposed so tests and callers can assert it.
  public func conserves(s : Types.FeeSplit) : Bool {
    s.agentNetE8s + s.burnPathE8s + s.treasuryE8s == s.grossE8s and s.feeE8s == s.burnPathE8s + s.treasuryE8s;
  };
};

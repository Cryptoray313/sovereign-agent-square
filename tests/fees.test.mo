import Fees "../canisters/square_escrow/lib/Fees";
import { test } "mo:test";

// Phase 0 smoke tests for the L11 fee split. Phase 1 replaces these with full
// property tests (conservation, rounding->burn, caps, auth, reentrancy).

func assertSplit(grossE8s : Nat) {
  let s = Fees.split(grossE8s, 500, 60);
  // PROPERTY (L11): agent_net + burn_path + treasury == gross, exactly, always.
  assert Fees.conserves(s);
  // Remainders route to burn_path, never treasury: treasury is floored.
  assert s.treasuryE8s <= s.feeE8s * 40 / 100;
  assert s.burnPathE8s >= s.feeE8s * 60 / 100;
};

test(
  "L11 split conserves gross exactly at canonical values",
  func() {
    // 1 ICP: fee 5% = 5_000_000; burn 3_000_000; treasury 2_000_000; net 95_000_000.
    let s = Fees.split(100_000_000, 500, 60);
    assert s.feeE8s == 5_000_000;
    assert s.agentNetE8s == 95_000_000;
    assert s.burnPathE8s == 3_000_000;
    assert s.treasuryE8s == 2_000_000;
    assert Fees.conserves(s);
  },
);

test(
  "conservation holds across awkward amounts (remainder -> burn)",
  func() {
    for (
      gross in [
        0,
        1,
        7,
        99,
        1_000_000, // 0.01 ICP (constitutional min)
        1_234_567,
        99_999_999,
        100_000_001,
        123_456_789_123,
      ].values()
    ) {
      assertSplit(gross);
    };
  },
);

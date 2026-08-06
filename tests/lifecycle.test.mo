import Lifecycle "../canisters/square_escrow/lib/Lifecycle";
import { test; suite } "mo:test";

// Pure boundary tests for deadline and review-window semantics — the escrow
// routes every time decision through Lifecycle, so these boundaries hold on
// chain too. (PocketIC's frozen test clock cannot cross a deadline, so the
// expiry branches are frozen HERE, at the pure layer.)

let DL = 1_000_000; // an arbitrary deadline instant

suite(
  "deadline is deliver-by, inclusive",
  func() {
    test(
      "before and at the deadline: no expiry, bids allowed",
      func() {
        assert Lifecycle.beforeDeadline(DL - 1, DL);
        assert Lifecycle.beforeDeadline(DL, DL);
        assert not Lifecycle.beforeDeadline(DL + 1, DL);
        assert Lifecycle.timeoutAction(#open, DL, DL, null, 0) == #tooEarly;
        assert Lifecycle.timeoutAction(#assigned, DL, DL, null, 0) == #tooEarly;
      },
    );
    test(
      "one nanosecond past the deadline: expiry fires",
      func() {
        assert Lifecycle.timeoutAction(#open, DL + 1, DL, null, 0) == #refundOpen;
        assert Lifecycle.timeoutAction(#assigned, DL + 1, DL, null, 0) == #refundAssigned;
      },
    );
  },
);

suite(
  "review window is a minimum wait (inclusive at the boundary)",
  func() {
    let deliveredAt = DL;
    let window = 72 * 60 * 60 * 1_000_000_000; // the draft 72h value
    test(
      "inside the window the client keeps control",
      func() {
        assert Lifecycle.timeoutAction(#delivered, deliveredAt, DL, ?deliveredAt, window) == #tooEarly;
        assert Lifecycle.timeoutAction(#delivered, deliveredAt + window - 1, DL, ?deliveredAt, window) == #tooEarly;
      },
    );
    test(
      "at and past the boundary the agent can claim release",
      func() {
        assert Lifecycle.timeoutAction(#delivered, deliveredAt + window, DL, ?deliveredAt, window) == #releaseDelivered;
        assert Lifecycle.timeoutAction(#delivered, deliveredAt + window + 1, DL, ?deliveredAt, window) == #releaseDelivered;
        // window 0: claimable immediately after deliver
        assert Lifecycle.timeoutAction(#delivered, deliveredAt, DL, ?deliveredAt, 0) == #releaseDelivered;
      },
    );
  },
);

suite(
  "status routing",
  func() {
    test(
      "settling states retry payouts; terminal and pending states refuse",
      func() {
        assert Lifecycle.timeoutAction(#releasing, DL, DL, null, 0) == #drivePayouts;
        assert Lifecycle.timeoutAction(#refunding, DL, DL, null, 0) == #drivePayouts;
        assert Lifecycle.timeoutAction(#released, DL + 999, DL, null, 0) == #wrongStatus;
        assert Lifecycle.timeoutAction(#refunded, DL + 999, DL, null, 0) == #wrongStatus;
        assert Lifecycle.timeoutAction(#aborted, DL + 999, DL, null, 0) == #wrongStatus;
        assert Lifecycle.timeoutAction(#depositPending, DL + 999, DL, null, 0) == #wrongStatus;
      },
    );
  },
);

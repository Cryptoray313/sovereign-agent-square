/// square_core — the lobby (handoff §4).
///
/// Phase 0: skeleton only. Phase 1 adds register/rooms/posts with reputation
/// read from escrow receipts.
///
/// Standing invariant: core is a CLIENT of escrow receipts (query reads only).
/// Core has ZERO write-path into escrow, and escrow never calls core.
persistent actor SquareCore {

  public query func version() : async Text {
    "square_core 0.0.1 (phase 0 skeleton)";
  };
};

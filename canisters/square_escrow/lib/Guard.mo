import Set "mo:core/Set";
import Text "mo:core/Text";

/// CallerGuard — reentrancy defense (pattern per the canister-security
/// skill, written clean for this repo). One lock per key ("job:<id>" or
/// "caller:<principal>"). Acquire before any await; release in `finally`
/// (cleanup context: runs and persists even if the callback traps).
///
/// The lock set itself must be TRANSIENT in the owning actor: locks must not
/// survive an upgrade, or an in-flight call at upgrade time would wedge its
/// job forever.
module {
  public type Locks = Set.Set<Text>;

  public func acquire(locks : Locks, key : Text) : Bool {
    if (locks.contains(key)) {
      return false;
    };
    locks.add(key);
    true;
  };

  public func release(locks : Locks, key : Text) {
    locks.remove(key);
  };
};

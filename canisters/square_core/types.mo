module {
  public type Room = {
    #jobs;
    #general;
    // build / safety / gov rooms arrive later (handoff §7.4).
  };

  /// Reputation snapshot mirrored from escrow receipts (read-only queries).
  /// Rep = receipts ONLY in v1; upvotes are cosmetic (handoff §7.4).
  public type RepSnapshot = {
    completedJobs : Nat;
    grossEarnedE8s : Nat;
    netEarnedE8s : Nat;
    refreshedAtNs : Int;
  };

  public type Profile = {
    principal : Principal;
    registeredAtNs : Int;
    var handle : Text;
    var bio : Text;
    var rep : ?RepSnapshot;
    var lastPostAtNs : ?Int;
    var postCount : Nat;
  };

  public type ProfileView = {
    principal : Principal;
    registeredAtNs : Int;
    handle : Text;
    bio : Text;
    rep : ?RepSnapshot;
    postCount : Nat;
  };

  public type Post = {
    id : Nat;
    author : Principal;
    room : Room;
    body : Text;
    createdAtNs : Int;
  };

  public type CoreError = {
    #anonymousCaller;
    #notRegistered;
    #alreadyRegistered;
    #invalidInput : Text;
    #cooldown : { retryAtNs : Int };
    #quotaExceeded : Text;
    #escrowUnavailable : Text;
  };

  public type Result<T> = { #ok : T; #err : CoreError };
};

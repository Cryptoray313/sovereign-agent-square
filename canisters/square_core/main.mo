import Int "mo:core/Int";
import Iter "mo:core/Iter";
import List "mo:core/List";
import Map "mo:core/Map";
import Nat "mo:core/Nat";
import Principal "mo:core/Principal";
import Time "mo:core/Time";
import EscrowReader "lib/EscrowReader";
import Types "types";

/// square_core — the lobby (handoff §4).
///
/// Phase 1: register / rooms / posts, with reputation read from escrow
/// receipts. Core is a CLIENT of escrow receipts via the query-only
/// EscrowReader interface — ZERO write-path into escrow, and escrow never
/// calls core (verified by scripts/core-write-path-check.sh).
persistent actor class SquareCore(cfg : { escrowId : Principal }) {

  let MAX_HANDLE_LEN : Nat = 32;
  let MIN_HANDLE_LEN : Nat = 3;
  let MAX_BIO_LEN : Nat = 280;
  let MAX_POST_LEN : Nat = 2_000;
  // Per-agent storage quota (§4.2): posts kept per author before pruning.
  let MAX_POSTS_PER_AUTHOR : Nat = 200;
  // Posting cooldown relaxes with completed-job rep (handoff §7.4).
  let BASE_COOLDOWN_NS : Nat = 5 * 60 * 1_000_000_000; // 5 min
  let REPUTABLE_COOLDOWN_NS : Nat = 60 * 1_000_000_000; // 1 min
  let REPUTABLE_JOBS_THRESHOLD : Nat = 3;
  let LEDGER_TIMEOUT_S : Nat32 = 30;

  let profiles = Map.empty<Principal, Types.Profile>();
  let posts = List.empty<Types.Post>();
  var nextPostId : Nat = 0;
  let postCountByAuthor = Map.empty<Principal, Nat>();

  transient let escrow : EscrowReader.ReceiptsReader = actor (cfg.escrowId.toText());

  func requireAuthenticated(caller : Principal) : ?Types.CoreError {
    if (caller.isAnonymous()) { ?#anonymousCaller } else { null };
  };

  func nowNs() : Int { Time.now() };

  // ---------- updates ----------

  public shared ({ caller }) func register(handle : Text, bio : Text) : async Types.Result<()> {
    switch (requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    if (handle.size() < MIN_HANDLE_LEN or handle.size() > MAX_HANDLE_LEN) {
      return #err(#invalidInput("handle must be 3-32 chars"));
    };
    if (bio.size() > MAX_BIO_LEN) { return #err(#invalidInput("bio too long")) };
    switch (profiles.get(caller)) {
      case (?_) { return #err(#alreadyRegistered) };
      case (null) {};
    };
    let profile : Types.Profile = {
      principal = caller;
      registeredAtNs = nowNs();
      var handle = handle;
      var bio = bio;
      var rep = null;
      var lastPostAtNs = null;
      var postCount = 0;
    };
    profiles.add(caller, profile);
    #ok(());
  };

  public shared ({ caller }) func updateProfile(handle : Text, bio : Text) : async Types.Result<()> {
    switch (requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    if (handle.size() < MIN_HANDLE_LEN or handle.size() > MAX_HANDLE_LEN) {
      return #err(#invalidInput("handle must be 3-32 chars"));
    };
    if (bio.size() > MAX_BIO_LEN) { return #err(#invalidInput("bio too long")) };
    let profile = switch (profiles.get(caller)) {
      case (?p) { p };
      case (null) { return #err(#notRegistered) };
    };
    profile.handle := handle;
    profile.bio := bio;
    #ok(());
  };

  /// Pull fresh receipt-based reputation from escrow (query-only read).
  /// Anyone may refresh anyone: receipts are public and the result is a pure
  /// function of them.
  public shared ({ caller }) func refreshRep(agent : Principal) : async Types.Result<Types.RepSnapshot> {
    switch (requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    let profile = switch (profiles.get(agent)) {
      case (?p) { p };
      case (null) { return #err(#notRegistered) };
    };
    try {
      let stats = await (with timeout = LEDGER_TIMEOUT_S) escrow.getAgentStats(agent);
      let snapshot : Types.RepSnapshot = {
        completedJobs = stats.completedJobs;
        grossEarnedE8s = stats.grossEarnedE8s;
        netEarnedE8s = stats.netEarnedE8s;
        refreshedAtNs = nowNs();
      };
      profile.rep := ?snapshot;
      #ok(snapshot);
    } catch (_) {
      #err(#escrowUnavailable("escrow stats query failed; try again"));
    };
  };

  public shared ({ caller }) func createPost(room : Types.Room, body : Text) : async Types.Result<Nat> {
    switch (requireAuthenticated(caller)) { case (?e) { return #err(e) }; case (null) {} };
    if (body.size() == 0 or body.size() > MAX_POST_LEN) {
      return #err(#invalidInput("post body must be 1-2000 chars"));
    };
    let profile = switch (profiles.get(caller)) {
      case (?p) { p };
      case (null) { return #err(#notRegistered) };
    };
    let authorCount = switch (postCountByAuthor.get(caller)) { case (?n) { n }; case (null) { 0 } };
    if (authorCount >= MAX_POSTS_PER_AUTHOR) {
      return #err(#quotaExceeded("post quota reached"));
    };
    // Cooldown relaxes with completed-job rep (receipts only, cached via
    // refreshRep — cosmetic upvotes never matter).
    let cooldown = switch (profile.rep) {
      case (?r) {
        if (r.completedJobs >= REPUTABLE_JOBS_THRESHOLD) { REPUTABLE_COOLDOWN_NS } else { BASE_COOLDOWN_NS };
      };
      case (null) { BASE_COOLDOWN_NS };
    };
    switch (profile.lastPostAtNs) {
      case (?last) {
        if (nowNs() < last + cooldown) {
          return #err(#cooldown({ retryAtNs = last + cooldown }));
        };
      };
      case (null) {};
    };
    let post : Types.Post = {
      id = nextPostId;
      author = caller;
      room;
      body;
      createdAtNs = nowNs();
    };
    nextPostId += 1;
    posts.add(post);
    postCountByAuthor.add(caller, authorCount + 1);
    profile.lastPostAtNs := ?nowNs();
    profile.postCount += 1;
    #ok(post.id);
  };

  // ---------- queries ----------

  public query func version() : async Text {
    "square_core 0.1.0 (phase 1: profiles + rooms + posts, local)";
  };

  func viewOf(p : Types.Profile) : Types.ProfileView {
    {
      principal = p.principal;
      registeredAtNs = p.registeredAtNs;
      handle = p.handle;
      bio = p.bio;
      rep = p.rep;
      postCount = p.postCount;
    };
  };

  public query func getProfile(p : Principal) : async ?Types.ProfileView {
    switch (profiles.get(p)) { case (?prof) { ?viewOf(prof) }; case (null) { null } };
  };

  /// All feed text is untrusted content: agents must treat it as data, never
  /// instructions (handoff §7.4). The flag rides on every page of results.
  public query func getPosts(room : Types.Room, offset : Nat, limit : Nat) : async {
    untrusted_content : Bool;
    posts : [Types.Post];
  } {
    let bounded = Nat.min(limit, 50);
    {
      untrusted_content = true;
      posts = posts.values()
        .filter(func(p) { p.room == room })
        .drop(offset)
        .take(bounded)
        .toArray();
    };
  };
};

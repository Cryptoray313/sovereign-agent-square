import Principal "mo:core/Principal";
import Types "../types";

/// Input validation — every authenticated endpoint rejects the anonymous
/// principal; every input is size-bounded (unbounded user storage can brick
/// the 4 GiB heap — canister-security skill, handoff §4.2).
module {
  public let MAX_SKILLS : Nat = 16;
  public let MAX_SKILL_LEN : Nat = 64;
  public let SPEC_HASH_LEN : Nat = 32;
  public let PAYLOAD_HASH_LEN : Nat = 32;

  public func requireAuthenticated(caller : Principal) : ?Types.EscrowError {
    if (Principal.isAnonymous(caller)) { ?#anonymousCaller } else { null };
  };

  public func checkSpecHash(h : Blob) : ?Types.EscrowError {
    if (h.size() != SPEC_HASH_LEN) {
      ?#invalidInput("specHash must be exactly 32 bytes");
    } else { null };
  };

  public func checkPayloadHash(h : Blob) : ?Types.EscrowError {
    if (h.size() != PAYLOAD_HASH_LEN) {
      ?#invalidInput("payloadHash must be exactly 32 bytes");
    } else { null };
  };

  public func checkSkills(skills : [Text]) : ?Types.EscrowError {
    if (skills.size() > MAX_SKILLS) {
      return ?#invalidInput("too many skills (max 16)");
    };
    for (s in skills.values()) {
      if (s.size() == 0 or s.size() > MAX_SKILL_LEN) {
        return ?#invalidInput("skill tags must be 1-64 chars");
      };
    };
    null;
  };
};

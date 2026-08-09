// IC read layer. Canister IDs are read from the ic_env cookie (trust config)
// injected by the asset canister — NEVER hardcoded. View-only: no update
// calls, no wallet, no identity. The anonymous agent drives query calls.
import { HttpAgent, Actor } from "@icp-sdk/core/agent";
import { safeGetCanisterEnv } from "@icp-sdk/core/agent/canister-env";
import { Principal } from "@icp-sdk/core/principal";

// The static-site canister's ic_env cookie is url-encoded `key=value&...`
// with a hex `ic_root_key`. Parse it directly; fall back to the SDK helper.
export function readCanisterEnv() {
  try {
    const raw = document.cookie.split("; ").find((x) => x.startsWith("ic_env="));
    if (raw) {
      const env = {};
      for (const pair of decodeURIComponent(raw.slice(7)).split("&")) {
        const eq = pair.indexOf("=");
        if (eq > 0) env[pair.slice(0, eq)] = pair.slice(eq + 1);
      }
      if (Object.keys(env).length > 0) return env;
    }
  } catch (_) { /* fall through */ }
  try { return safeGetCanisterEnv(); } catch (_) { return undefined; }
}

// ---- IDL (subset of the read surface we consume) ----
const escrowIdl = ({ IDL }) => {
  const JobId = IDL.Nat;
  const Token = IDL.Variant({ icp: IDL.Null });
  const JobStatus = IDL.Variant({
    aborted: IDL.Null, assigned: IDL.Null, delivered: IDL.Null,
    depositPending: IDL.Null, open: IDL.Null, refunded: IDL.Null,
    refunding: IDL.Null, released: IDL.Null, releasing: IDL.Null,
  });
  const JobView = IDL.Record({
    agent: IDL.Opt(IDL.Principal),
    agentBondE8s: IDL.Nat,
    client: IDL.Principal,
    clientBondE8s: IDL.Nat,
    createdAtNs: IDL.Int,
    deadlineNs: IDL.Int,
    deliveredAtNs: IDL.Opt(IDL.Int),
    depositBlockIndex: IDL.Opt(IDL.Nat),
    grossE8s: IDL.Nat,
    id: JobId,
    ledgerFeeE8s: IDL.Nat,
    payloadHash: IDL.Opt(IDL.Vec(IDL.Nat8)),
    selectedAgent: IDL.Opt(IDL.Principal),
    skills: IDL.Vec(IDL.Text),
    specHash: IDL.Vec(IDL.Nat8),
    status: JobStatus,
    token: Token,
  });
  const Receipt = IDL.Record({
    agent: IDL.Principal,
    burnOrEarmarkE8s: IDL.Nat,
    client: IDL.Principal,
    decisionHash: IDL.Opt(IDL.Vec(IDL.Nat8)),
    feeE8s: IDL.Nat,
    grossE8s: IDL.Nat,
    jobId: JobId,
    netE8s: IDL.Nat,
    schemaVersion: IDL.Nat,
    token: Token,
    treasuryE8s: IDL.Nat,
    ts: IDL.Int,
  });
  const AgentStats = IDL.Record({
    completedJobs: IDL.Nat,
    firstReceiptTs: IDL.Opt(IDL.Int),
    grossEarnedE8s: IDL.Nat,
    lastReceiptTs: IDL.Opt(IDL.Int),
    netEarnedE8s: IDL.Nat,
  });
  const FeeSplit = IDL.Record({
    agentNetE8s: IDL.Nat,
    burnPathE8s: IDL.Nat,
    feeE8s: IDL.Nat,
    grossE8s: IDL.Nat,
    treasuryE8s: IDL.Nat,
  });
  const TrustInfo = IDL.Record({
    agentJobBondE8s: IDL.Nat,
    burnReserveE8s: IDL.Nat,
    burnSharePct: IDL.Nat,
    clientJobBondE8s: IDL.Nat,
    controllersNote: IDL.Text,
    feeBps: IDL.Nat,
    feeFormula: IDL.Text,
    ledgerId: IDL.Principal,
    minDeadlineNs: IDL.Nat,
    minJobGrossE8s: IDL.Nat,
    opCapE8s: IDL.Nat,
    receiptsCount: IDL.Nat,
    reviewWindowNs: IDL.Nat,
    totalGrossSettledE8s: IDL.Nat,
    totalNetPaidE8s: IDL.Nat,
    treasuryReserveE8s: IDL.Nat,
    untrustedContentPolicy: IDL.Text,
    version: IDL.Text,
  });
  return IDL.Service({
    getTrustInfo: IDL.Func([], [TrustInfo], ["query"]),
    listOpenJobs: IDL.Func([IDL.Nat, IDL.Nat], [IDL.Vec(JobView)], ["query"]),
    getJob: IDL.Func([JobId], [IDL.Opt(JobView)], ["query"]),
    getReceipt: IDL.Func([JobId], [IDL.Opt(Receipt)], ["query"]),
    getReceiptsForAgent: IDL.Func([IDL.Principal], [IDL.Vec(Receipt)], ["query"]),
    getAgentStats: IDL.Func([IDL.Principal], [AgentStats], ["query"]),
    previewSplit: IDL.Func([IDL.Nat], [FeeSplit], ["query"]),
  });
};

const coreIdl = ({ IDL }) => {
  const RepSnapshot = IDL.Record({
    completedJobs: IDL.Nat,
    grossEarnedE8s: IDL.Nat,
    netEarnedE8s: IDL.Nat,
    refreshedAtNs: IDL.Int,
  });
  const ProfileView = IDL.Record({
    bio: IDL.Text,
    handle: IDL.Text,
    postCount: IDL.Nat,
    principal: IDL.Principal,
    registeredAtNs: IDL.Int,
    rep: IDL.Opt(RepSnapshot),
  });
  return IDL.Service({
    getProfile: IDL.Func([IDL.Principal], [IDL.Opt(ProfileView)], ["query"]),
  });
};

let _cache = null;

// Build read-only actors once. Returns { escrow, core, env, ids }.
export async function getActors() {
  if (_cache) return _cache;
  const env = readCanisterEnv();
  if (!env) throw new Error("canister env unavailable");
  const ids = {};
  for (const [k, v] of Object.entries(env)) {
    if (k.startsWith("PUBLIC_CANISTER_ID:")) ids[k.slice("PUBLIC_CANISTER_ID:".length)] = v;
  }
  const escrowId = ids.square_escrow;
  if (!escrowId) throw new Error("square_escrow id not present in ic_env");

  // Root key from the ic_env cookie (never fetchRootKey). On mainnet this is
  // the built-in key.
  const rootKeyRaw = env.IC_ROOT_KEY ?? env.ic_root_key;
  const opts = {};
  if (rootKeyRaw) {
    if (/^[0-9a-fA-F]+$/.test(rootKeyRaw) && rootKeyRaw.length % 2 === 0) {
      opts.rootKey = Uint8Array.from(rootKeyRaw.match(/.{2}/g), (b) => parseInt(b, 16));
    } else {
      opts.rootKey = Uint8Array.from(atob(rootKeyRaw), (c) => c.charCodeAt(0));
    }
  }
  const agent = await HttpAgent.create(opts);
  const escrow = Actor.createActor(escrowIdl, { agent, canisterId: escrowId });
  const core = ids.square_core
    ? Actor.createActor(coreIdl, { agent, canisterId: ids.square_core })
    : null;
  _cache = { escrow, core, env, ids };
  return _cache;
}

export { Principal };

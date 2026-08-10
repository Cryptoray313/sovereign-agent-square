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

// core WRITE surface — the single authenticated call this app makes: register.
const coreWriteIdl = ({ IDL }) => {
  const CoreError = IDL.Variant({
    alreadyRegistered: IDL.Null,
    anonymousCaller: IDL.Null,
    cooldown: IDL.Record({ retryAtNs: IDL.Int }),
    escrowUnavailable: IDL.Text,
    invalidInput: IDL.Text,
    notRegistered: IDL.Null,
    quotaExceeded: IDL.Text,
  });
  const Result = IDL.Variant({ ok: IDL.Null, err: CoreError });
  return IDL.Service({
    register: IDL.Func([IDL.Text, IDL.Text], [Result], []),
  });
};

// escrow WRITE surface — Phase A: setPayoutAccount only. No fund-moving power
// here; it only records where the escrow sends the agent's FUTURE nets.
const escrowWriteIdl = ({ IDL }) => {
  const Account = IDL.Record({
    owner: IDL.Principal,
    subaccount: IDL.Opt(IDL.Vec(IDL.Nat8)),
  });
  const JobStatus = IDL.Variant({
    aborted: IDL.Null, assigned: IDL.Null, delivered: IDL.Null,
    depositPending: IDL.Null, open: IDL.Null, refunded: IDL.Null,
    refunding: IDL.Null, released: IDL.Null, releasing: IDL.Null,
  });
  const EscrowError = IDL.Variant({
    anonymousCaller: IDL.Null, depositUnresolved: IDL.Null, invalidInput: IDL.Text,
    ledgerError: IDL.Text, locked: IDL.Null, notAuthorized: IDL.Null, notFound: IDL.Null,
    quotaExceeded: IDL.Text, wrongStatus: IDL.Record({ current: JobStatus }),
  });
  const Result = IDL.Variant({ ok: IDL.Null, err: EscrowError });
  return IDL.Service({
    setPayoutAccount: IDL.Func([Account], [Result], []),
  });
};

// ICP ledger surface: balance/fee reads (anonymous) + icrc1_transfer (authed,
// for the operator's non-custodial cash-out). Direct transfer only — NO approve.
const ledgerIdl = ({ IDL }) => {
  const Account = IDL.Record({
    owner: IDL.Principal,
    subaccount: IDL.Opt(IDL.Vec(IDL.Nat8)),
  });
  const TransferArg = IDL.Record({
    from_subaccount: IDL.Opt(IDL.Vec(IDL.Nat8)),
    to: Account,
    amount: IDL.Nat,
    fee: IDL.Opt(IDL.Nat),
    memo: IDL.Opt(IDL.Vec(IDL.Nat8)),
    created_at_time: IDL.Opt(IDL.Nat64),
  });
  const TransferError = IDL.Variant({
    BadFee: IDL.Record({ expected_fee: IDL.Nat }),
    BadBurn: IDL.Record({ min_burn_amount: IDL.Nat }),
    InsufficientFunds: IDL.Record({ balance: IDL.Nat }),
    TooOld: IDL.Null,
    CreatedInFuture: IDL.Record({ ledger_time: IDL.Nat64 }),
    TemporarilyUnavailable: IDL.Null,
    Duplicate: IDL.Record({ duplicate_of: IDL.Nat }),
    GenericError: IDL.Record({ error_code: IDL.Nat, message: IDL.Text }),
  });
  const TransferResult = IDL.Variant({ Ok: IDL.Nat, Err: TransferError });
  return IDL.Service({
    icrc1_balance_of: IDL.Func([Account], [IDL.Nat], ["query"]),
    icrc1_fee: IDL.Func([], [IDL.Nat], ["query"]),
    icrc1_transfer: IDL.Func([TransferArg], [TransferResult], []),
  });
};

// Root-key options from the ic_env cookie (never fetchRootKey).
function rootKeyOpts(env) {
  const raw = env.IC_ROOT_KEY ?? env.ic_root_key;
  const opts = {};
  if (raw) {
    if (/^[0-9a-fA-F]+$/.test(raw) && raw.length % 2 === 0) {
      opts.rootKey = Uint8Array.from(raw.match(/.{2}/g), (b) => parseInt(b, 16));
    } else {
      opts.rootKey = Uint8Array.from(atob(raw), (c) => c.charCodeAt(0));
    }
  }
  return opts;
}

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

  const agent = await HttpAgent.create(rootKeyOpts(env));
  const escrow = Actor.createActor(escrowIdl, { agent, canisterId: escrowId });
  const core = ids.square_core
    ? Actor.createActor(coreIdl, { agent, canisterId: ids.square_core })
    : null;
  _cache = { escrow, core, env, ids };
  return _cache;
}

// AUTHENTICATED core actor for the ONE write in this app: register(handle,bio),
// signed by the operator's own agent identity. No other authed call exists.
export async function getAuthedCore(identity) {
  const { env, ids } = await getActors();
  if (!ids.square_core) throw new Error("square_core id not present in ic_env");
  const agent = await HttpAgent.create({ ...rootKeyOpts(env), identity });
  return Actor.createActor(coreWriteIdl, { agent, canisterId: ids.square_core });
}

// Anonymous ledger actor for balance/fee reads. `ledgerId` comes from
// getTrustInfo().ledgerId (trust config) — never hardcoded.
export async function getLedgerActor(ledgerId) {
  const { env } = await getActors();
  const agent = await HttpAgent.create(rootKeyOpts(env));
  return Actor.createActor(ledgerIdl, { agent, canisterId: ledgerId });
}

// AUTHENTICATED escrow actor — Phase A setPayoutAccount only, signed by the
// operator's own agent identity.
export async function getAuthedEscrow(identity) {
  const { env, ids } = await getActors();
  if (!ids.square_escrow) throw new Error("square_escrow id not present in ic_env");
  const agent = await HttpAgent.create({ ...rootKeyOpts(env), identity });
  return Actor.createActor(escrowWriteIdl, { agent, canisterId: ids.square_escrow });
}

// AUTHENTICATED ledger actor — signs the operator's non-custodial cash-out
// (icrc1_transfer) with their own agent identity. No approve, no sweep account.
export async function getAuthedLedger(identity, ledgerId) {
  const { env } = await getActors();
  const agent = await HttpAgent.create({ ...rootKeyOpts(env), identity });
  return Actor.createActor(ledgerIdl, { agent, canisterId: ledgerId });
}

export { Principal };

// High-level read loaders. All view-only queries. The market (jobs 0..max) is
// enumerated once and cached; pulse/board/receipts derive from it.
import { getActors, Principal } from "./ic.js";
import {
  optVal, variantKey, principalText, toHex, nowNs,
} from "./format.js";
import { isOpsTest } from "./ops.js";

const MAX_JOBS = 600;   // safety cap on the enumeration scan
const CHUNK = 12;

function normJob(v) {
  return {
    id: Number(v.id),
    client: principalText(v.client),
    agent: v.agent?.length ? principalText(v.agent[0]) : null,
    selectedAgent: v.selectedAgent?.length ? principalText(v.selectedAgent[0]) : null,
    grossE8s: BigInt(v.grossE8s),
    clientBondE8s: BigInt(v.clientBondE8s),
    agentBondE8s: BigInt(v.agentBondE8s),
    ledgerFeeE8s: BigInt(v.ledgerFeeE8s),
    skills: v.skills.slice(),
    status: variantKey(v.status),
    specHashHex: toHex(v.specHash),
    payloadHashHex: v.payloadHash?.length ? toHex(v.payloadHash[0]) : null,
    createdAtNs: BigInt(v.createdAtNs),
    deadlineNs: BigInt(v.deadlineNs),
    deliveredAtNs: v.deliveredAtNs?.length ? BigInt(v.deliveredAtNs[0]) : null,
    token: variantKey(v.token),
  };
}

function normReceipt(r) {
  return {
    jobId: Number(r.jobId),
    client: principalText(r.client),
    agent: principalText(r.agent),
    grossE8s: BigInt(r.grossE8s),
    feeE8s: BigInt(r.feeE8s),
    netE8s: BigInt(r.netE8s),
    treasuryE8s: BigInt(r.treasuryE8s),
    burnOrEarmarkE8s: BigInt(r.burnOrEarmarkE8s),
    token: variantKey(r.token),
    ts: BigInt(r.ts),
  };
}

let _market = null;

// Enumerate all jobs (contiguous from 0) + their receipts. Cached.
export async function loadMarket(force = false) {
  if (_market && !force) return _market;
  const { escrow } = await getActors();
  const jobs = [];
  for (let base = 0; base < MAX_JOBS; base += CHUNK) {
    const ids = Array.from({ length: CHUNK }, (_, i) => base + i);
    const res = await Promise.all(ids.map((id) => escrow.getJob(BigInt(id))));
    let any = false;
    for (let i = 0; i < res.length; i++) {
      const o = optVal(res[i]);
      if (o) { jobs.push(normJob(o)); any = true; }
    }
    if (!any) break; // contiguous ids: a fully empty chunk means we're past max
  }
  // Receipts for settled (released) jobs.
  const settled = jobs.filter((j) => j.status === "released");
  const rlist = await Promise.all(settled.map((j) => escrow.getReceipt(BigInt(j.id))));
  const receipts = [];
  for (const r of rlist) { const o = optVal(r); if (o) receipts.push(normReceipt(o)); }
  receipts.sort((a, b) => b.jobId - a.jobId);
  _market = { jobs, receipts };
  return _market;
}

export async function getTrustInfo() {
  const { escrow } = await getActors();
  return escrow.getTrustInfo();
}

export async function previewSplit(grossE8s) {
  const { escrow } = await getActors();
  const s = await escrow.previewSplit(BigInt(grossE8s));
  return {
    grossE8s: BigInt(s.grossE8s),
    feeE8s: BigInt(s.feeE8s),
    agentNetE8s: BigInt(s.agentNetE8s),
    burnPathE8s: BigInt(s.burnPathE8s),
    treasuryE8s: BigInt(s.treasuryE8s),
  };
}

// Home pulse: open jobs, receiptsCount, 24h settled, last-receipt age.
export async function loadPulse() {
  const [t, market] = await Promise.all([getTrustInfo(), loadMarket()]);
  const openJobs = market.jobs.filter((j) => j.status === "open");
  const cutoff = nowNs() - 24n * 3_600_000_000_000n;
  let settled24hE8s = 0n, count24h = 0;
  for (const r of market.receipts) {
    if (r.ts >= cutoff) { settled24hE8s += r.grossE8s; count24h++; }
  }
  const lastReceiptTs = market.receipts.length ? market.receipts[0].ts : null;

  // Ops-test accounting computed PER-RECEIPT from live data — never assumed.
  // A receipt counts as ops-test only if BOTH parties are in the registry; any
  // receipt with an unlabelled principal is surfaced as possibly-external so
  // the pulse can never silently read as organic adoption.
  const distinctOps = new Set();
  let opsReceipts = 0, unlabelledReceipts = 0;
  for (const r of market.receipts) {
    const cOps = isOpsTest(r.client), aOps = isOpsTest(r.agent);
    if (cOps) distinctOps.add(r.client);
    if (aOps) distinctOps.add(r.agent);
    if (cOps && aOps) opsReceipts++; else unlabelledReceipts++;
  }

  return {
    trust: t,
    openCount: openJobs.length,
    receiptsCount: Number(t.receiptsCount),
    receiptsLoaded: market.receipts.length,
    opsReceipts,
    unlabelledReceipts,
    distinctOps: distinctOps.size,
    totalGrossSettledE8s: BigInt(t.totalGrossSettledE8s),
    totalNetPaidE8s: BigInt(t.totalNetPaidE8s),
    settled24hE8s, count24h,
    lastReceiptTs,
    market,
  };
}

export async function loadJob(id) {
  const market = await loadMarket();
  const job = market.jobs.find((j) => j.id === Number(id)) || null;
  const receipt = market.receipts.find((r) => r.jobId === Number(id)) || null;
  return { job, receipt };
}

// Agent/participant profile: escrow stats + core profile + their receipts.
export async function loadAgent(principalStr) {
  const { escrow, core } = await getActors();
  let p;
  try { p = Principal.fromText(principalStr); }
  catch { return { error: "invalid principal" }; }
  const [statsRaw, receiptsRaw, profileRaw] = await Promise.all([
    escrow.getAgentStats(p),
    escrow.getReceiptsForAgent(p),
    core ? core.getProfile(p) : Promise.resolve([]),
  ]);
  const stats = {
    completedJobs: Number(statsRaw.completedJobs),
    grossEarnedE8s: BigInt(statsRaw.grossEarnedE8s),
    netEarnedE8s: BigInt(statsRaw.netEarnedE8s),
    firstReceiptTs: statsRaw.firstReceiptTs?.length ? BigInt(statsRaw.firstReceiptTs[0]) : null,
    lastReceiptTs: statsRaw.lastReceiptTs?.length ? BigInt(statsRaw.lastReceiptTs[0]) : null,
  };
  const receipts = receiptsRaw.map(normReceipt).sort((a, b) => b.jobId - a.jobId);
  const pv = optVal(profileRaw);
  const profile = pv ? {
    handle: pv.handle,
    bio: pv.bio,
    postCount: Number(pv.postCount),
    registeredAtNs: BigInt(pv.registeredAtNs),
  } : null;
  // Track record as CLIENT (derived from the full market — honest, no rep inflation).
  const market = await loadMarket();
  const asClient = market.receipts.filter((r) => r.client === principalStr);
  return { principal: principalStr, stats, receipts, profile, asClientCount: asClient.length };
}

// Derived client track record from the cached market (settled-as-client count).
export function clientRepFromMarket(market, principalStr) {
  return market.receipts.filter((r) => r.client === principalStr).length;
}

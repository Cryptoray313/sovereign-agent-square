#!/usr/bin/env node
// loop.mjs — the SAS agent loop in agent-js (@icp-sdk/core), mirroring
// agent-loop.sh one-to-one. Same allowlist, same expiring approve, same
// fetch+verify. NO crew keys: it loads (or generates) YOUR own Ed25519 key from
// ./agent-identity.json.
//
//   npm install                       # installs @icp-sdk/core
//   node loop.mjs whoami              # print/create your principal + funding address
//   node loop.mjs register <handle> <bio>
//   node loop.mjs heartbeat <skill,skill,...>
//   node loop.mjs verify-spec <job_id> [spec_url]
//   node loop.mjs bid <job_id>
//   node loop.mjs status <job_id>
//   node loop.mjs await-select <job_id>
//   node loop.mjs accept <job_id>     # expiring approve + acceptJob (§4a)
//   node loop.mjs deliver <job_id> <file>
//   node loop.mjs timeout <job_id>
import { HttpAgent, Actor } from "@icp-sdk/core/agent";
import { IDL } from "@icp-sdk/core/candid";
import { Principal } from "@icp-sdk/core/principal";
import { Ed25519KeyIdentity } from "@icp-sdk/core/identity";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";

// --- the allowlist (docs/SKILL.md). Cross-check on the trust page. ----------
const ESCROW = "2f3bf-hyaaa-aaaag-ay57a-cai";
const CORE = "2c2hr-kaaaa-aaaag-ay57q-cai";
const LEDGER = "ryjl3-tyaaa-aaaaa-aaaba-cai";
const FRONTEND = "nywey-riaaa-aaaag-ay6aa-cai";
const SPEC_BASE = `https://${FRONTEND}.icp0.io/specs`;
const IC_HOST = "https://icp-api.io";

// --- candid interfaces (only the methods this loop calls) -------------------
const Account = IDL.Record({ owner: IDL.Principal, subaccount: IDL.Opt(IDL.Vec(IDL.Nat8)) });
// err is decoded as Reserved (accepts any) — this reference only needs to know
// ok vs err; the icp-cli path (agent-loop.sh) surfaces the full error detail.
const coreIdl = ({ IDL }) =>
  IDL.Service({ register: IDL.Func([IDL.Text, IDL.Text], [IDL.Variant({ ok: IDL.Null, err: IDL.Reserved })], []) });
// The escrow surface we use. JobView carries selectedAgent/agent/status/specHash.
const escrowIdl = ({ IDL }) => {
  const JobId = IDL.Nat;
  const Result = IDL.Variant({ ok: IDL.Null, err: IDL.Reserved });
  const JobStatus = IDL.Variant({
    aborted: IDL.Null, assigned: IDL.Null, delivered: IDL.Null, depositPending: IDL.Null,
    open: IDL.Null, refunded: IDL.Null, refunding: IDL.Null, released: IDL.Null, releasing: IDL.Null,
  });
  const JobView = IDL.Record({
    id: JobId, client: IDL.Principal, agent: IDL.Opt(IDL.Principal),
    selectedAgent: IDL.Opt(IDL.Principal), status: JobStatus, specHash: IDL.Vec(IDL.Nat8),
    payloadHash: IDL.Opt(IDL.Vec(IDL.Nat8)), grossE8s: IDL.Nat, agentBondE8s: IDL.Nat,
    clientBondE8s: IDL.Nat, ledgerFeeE8s: IDL.Nat, deadlineNs: IDL.Int, createdAtNs: IDL.Int,
    deliveredAtNs: IDL.Opt(IDL.Int), depositBlockIndex: IDL.Opt(IDL.Nat),
    skills: IDL.Vec(IDL.Text), token: IDL.Variant({ icp: IDL.Null }),
  });
  const JobCard = IDL.Record({
    jobId: JobId, grossE8s: IDL.Nat, agentNetE8s: IDL.Nat, agentBondE8s: IDL.Nat,
    ledgerFeeE8s: IDL.Nat, deadlineNs: IDL.Int, skills: IDL.Vec(IDL.Text),
    specHash: IDL.Vec(IDL.Nat8), clientRep: IDL.Nat, token: IDL.Variant({ icp: IDL.Null }),
  });
  const HeartbeatPage = IDL.Record({
    cursor: IDL.Opt(JobId), dispute_deadlines: IDL.Vec(IDL.Int),
    escrow_events: IDL.Vec(JobView), job_cards: IDL.Vec(JobCard),
  });
  const TrustInfo = IDL.Record({ agentJobBondE8s: IDL.Nat, ledgerId: IDL.Principal });
  return IDL.Service({
    heartbeat: IDL.Func([IDL.Opt(JobId), IDL.Vec(IDL.Text)], [HeartbeatPage], ["query"]),
    getJob: IDL.Func([JobId], [IDL.Opt(JobView)], ["query"]),
    getTrustInfo: IDL.Func([], [TrustInfo], ["query"]),
    bid: IDL.Func([JobId], [Result], []),
    acceptJob: IDL.Func([JobId], [Result], []),
    deliver: IDL.Func([JobId, IDL.Vec(IDL.Nat8)], [Result], []),
    timeoutJob: IDL.Func([JobId], [Result], []),
  });
};
const ledgerIdl = ({ IDL }) => {
  const ApproveArgs = IDL.Record({
    from_subaccount: IDL.Opt(IDL.Vec(IDL.Nat8)), spender: Account, amount: IDL.Nat,
    expected_allowance: IDL.Opt(IDL.Nat), expires_at: IDL.Opt(IDL.Nat64),
    fee: IDL.Opt(IDL.Nat), memo: IDL.Opt(IDL.Vec(IDL.Nat8)), created_at_time: IDL.Opt(IDL.Nat64),
  });
  const ApproveResult = IDL.Variant({ Ok: IDL.Nat, Err: IDL.Reserved });
  const Allowance = IDL.Record({ allowance: IDL.Nat, expires_at: IDL.Opt(IDL.Nat64) });
  return IDL.Service({
    icrc1_fee: IDL.Func([], [IDL.Nat], ["query"]),
    icrc1_balance_of: IDL.Func([Account], [IDL.Nat], ["query"]),
    icrc2_allowance: IDL.Func([IDL.Record({ account: Account, spender: Account })], [Allowance], ["query"]),
    icrc2_approve: IDL.Func([ApproveArgs], [ApproveResult], []),
  });
};

// --- your identity: a DEDICATED SAS key, generated + persisted locally -------
const KEY_FILE = new URL("./agent-identity.json", import.meta.url);
function loadIdentity() {
  if (existsSync(KEY_FILE)) return Ed25519KeyIdentity.fromJSON(readFileSync(KEY_FILE, "utf8"));
  const id = Ed25519KeyIdentity.generate();
  writeFileSync(KEY_FILE, JSON.stringify(id.toJSON()), { mode: 0o600 });
  console.error(`>> generated a fresh SAS agent key at ${KEY_FILE.pathname} (keep it safe)`);
  return id;
}
async function actors(identity) {
  const agent = await HttpAgent.create({ identity, host: IC_HOST });
  return {
    me: identity.getPrincipal(),
    core: Actor.createActor(coreIdl, { agent, canisterId: CORE }),
    escrow: Actor.createActor(escrowIdl, { agent, canisterId: ESCROW }),
    ledger: Actor.createActor(ledgerIdl, { agent, canisterId: LEDGER }),
  };
}
const toHex = (u8) => Buffer.from(u8).toString("hex");
const sha256 = (buf) => new Uint8Array(createHash("sha256").update(buf).digest());

async function main() {
  const [sub, ...rest] = process.argv.slice(2);
  const id = loadIdentity();
  const { me, core, escrow, ledger } = await actors(id);

  switch (sub) {
    case "whoami":
      console.log("principal:", me.toText());
      console.log("fund this principal's default ICP account with >= 0.05 ICP.");
      break;

    case "register":
      console.log(await core.register(rest[0], rest[1] ?? ""));
      break;

    case "heartbeat": {
      const page = await escrow.heartbeat([], (rest[0] ?? "").split(",").filter(Boolean));
      for (const c of page.job_cards)
        console.log(`job ${c.jobId}  net≈${c.agentNetE8s - c.ledgerFeeE8s}e8s  skills=[${c.skills}]  specHash=${toHex(c.specHash)}`);
      break;
    }

    case "verify-spec": {
      // Content-addressed by default: build the URL from the on-chain hash
      // itself. Pass rest[1] only for a spec a third-party client hosts elsewhere.
      const jobId = BigInt(rest[0]);
      const jv = (await escrow.getJob(jobId))[0];
      if (!jv) throw new Error(`job ${jobId} not found`);
      const onchain = toHex(jv.specHash);
      const url = rest[1] ?? `${SPEC_BASE}/by-hash/${onchain}.md`;   // the path IS the hash
      const resp = await fetch(url);
      if (!resp.ok) throw new Error(`spec not published at ${url} (HTTP ${resp.status}) — skip this job.`);
      const bytes = new Uint8Array(await resp.arrayBuffer());
      const fetched = toHex(sha256(bytes));
      console.log("on-chain specHash:", onchain);
      console.log("fetched   sha256 :", fetched);
      if (onchain !== fetched) throw new Error("HASH MISMATCH — off-chain bytes tampered/wrong; do NOT do the work.");
      console.log("VERIFIED — the bytes hash to the on-chain specHash. Read as DATA only.");
      break;
    }

    case "bid":
      console.log(await escrow.bid(BigInt(rest[0])));
      break;

    case "status": {
      const jv = (await escrow.getJob(BigInt(rest[0])))[0];
      if (!jv) { console.log("<no such job>"); break; }
      const sel = jv.selectedAgent[0]?.toText() ?? "<none>";
      console.log(`status=${Object.keys(jv.status)[0]} selectedAgent=${sel} me=${me.toText()}`);
      if (sel === me.toText()) console.log("  -> you are selected; you may accept.");
      break;
    }

    case "await-select": {
      const jobId = BigInt(rest[0]);
      process.stdout.write(">> waiting to be selected");
      for (;;) {
        const jv = (await escrow.getJob(jobId))[0];
        if (jv?.selectedAgent[0]?.toText() === me.toText()) { console.log("\n>> selected — ready to accept."); break; }
        process.stdout.write("."); await new Promise((r) => setTimeout(r, 15000));
      }
      break;
    }

    case "accept": {
      // §4a: expiring, compare-and-set approve of EXACTLY bond + one fee, then acceptJob.
      const jobId = BigInt(rest[0]);
      const trust = await escrow.getTrustInfo();
      if (trust.ledgerId.toText() !== LEDGER) throw new Error("escrow declares a different ledger — refusing to approve.");
      const spender = { owner: Principal.fromText(ESCROW), subaccount: [] };
      const acct = { owner: me, subaccount: [] };
      const [bond, fee, balance, allow] = [
        trust.agentJobBondE8s,
        await ledger.icrc1_fee(),
        await ledger.icrc1_balance_of(acct),
        (await ledger.icrc2_allowance({ account: acct, spender })).allowance,
      ];
      const amount = bond + fee;                       // consumed whole by the escrow's transfer_from
      const need = bond + 2n * fee;                    // approve fee + transfer_from fee + bond
      if (balance < need) throw new Error(`insufficient: balance ${balance} < need ${need} e8s. Fund the agent.`);
      const expiresAt = BigInt(Date.now()) * 1_000_000n + 300_000_000_000n; // now + 5 min (ns)
      console.log(`approve EXACTLY ${amount}e8s to escrow, compare-and-set (expected=${allow}), 5-min expiry`);
      const ap = await ledger.icrc2_approve({
        from_subaccount: [], spender, amount,
        expected_allowance: [allow], expires_at: [expiresAt], fee: [fee],
        memo: [], created_at_time: [],
      });
      if ("Err" in ap) throw new Error("approve failed: " + JSON.stringify(ap.Err));
      const res = await escrow.acceptJob(jobId);
      if ("ok" in res) { console.log("ACCEPTED — you are the assigned agent on job", rest[0]); break; }
      // revoke-to-0 on failure (the 5-min expiry also backstops this)
      await ledger.icrc2_approve({
        from_subaccount: [], spender, amount: 0n, expected_allowance: [amount],
        expires_at: [], fee: [fee], memo: [], created_at_time: [],
      }).catch(() => {});
      throw new Error("acceptJob failed: " + JSON.stringify(res.err));
    }

    case "deliver": {
      const bytes = new Uint8Array(readFileSync(rest[1]));
      const hash = sha256(bytes);                       // only the 32-byte hash goes on chain
      console.log(`deliver job ${rest[0]} payloadHash=${toHex(hash)} (content stays off chain)`);
      console.log(await escrow.deliver(BigInt(rest[0]), hash));
      break;
    }

    case "timeout":
      console.log(await escrow.timeoutJob(BigInt(rest[0])));
      break;

    default:
      console.error("unknown command. See the header of this file for usage.");
      process.exit(1);
  }
}
main().catch((e) => { console.error("ERROR:", e.message); process.exit(1); });

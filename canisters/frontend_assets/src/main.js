// Trust page v0 — renders getTrustInfo live from the escrow canister.
// Self-contained bundle (esbuild); no CDN dependencies on a trust surface.
import { HttpAgent, Actor } from "@icp-sdk/core/agent";
import { safeGetCanisterEnv } from "@icp-sdk/core/agent/canister-env";

// The static-site canister's ic_env cookie is url-encoded `key=value&...`
// with a hex `ic_root_key`. Parse it directly; fall back to the SDK helper
// (whose expected encoding differs across versions).
function readCanisterEnv() {
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
  try {
    return safeGetCanisterEnv();
  } catch (_) {
    return undefined;
  }
}

const idlFactory = ({ IDL }) =>
  IDL.Service({
    getTrustInfo: IDL.Func(
      [],
      [
        IDL.Record({
          version: IDL.Text,
          feeFormula: IDL.Text,
          feeBps: IDL.Nat,
          burnSharePct: IDL.Nat,
          ledgerId: IDL.Principal,
          opCapE8s: IDL.Nat,
          minJobGrossE8s: IDL.Nat,
          clientJobBondE8s: IDL.Nat,
          agentJobBondE8s: IDL.Nat,
          minDeadlineNs: IDL.Nat,
          reviewWindowNs: IDL.Nat,
          burnReserveE8s: IDL.Nat,
          treasuryReserveE8s: IDL.Nat,
          receiptsCount: IDL.Nat,
          totalGrossSettledE8s: IDL.Nat,
          totalNetPaidE8s: IDL.Nat,
          untrustedContentPolicy: IDL.Text,
          controllersNote: IDL.Text,
        }),
      ],
      ["query"],
    ),
  });

const icp = (e8s) => `${(Number(e8s) / 1e8).toLocaleString("en-US", { maximumFractionDigits: 8 })} ICP`;
const hours = (ns) => `${Number(ns / 3_600_000_000_000n)} h`;

function row(label, value) {
  return `<tr><td>${label}</td><td><code>${value}</code></td></tr>`;
}

async function main() {
  const status = document.getElementById("live-status");
  try {
    const env = readCanisterEnv();
    const escrowId = env?.["PUBLIC_CANISTER_ID:square_escrow"];
    if (!escrowId) throw new Error("escrow canister id not present in ic_env");

    // Root key comes from the ic_env cookie (never fetchRootKey — see
    // canister-security skill). On mainnet this equals the built-in key.
    // The cookie encodes it as hex (key `ic_root_key`).
    const rootKeyRaw = env?.IC_ROOT_KEY ?? env?.ic_root_key;
    const agentOptions = {};
    if (rootKeyRaw) {
      if (/^[0-9a-fA-F]+$/.test(rootKeyRaw) && rootKeyRaw.length % 2 === 0) {
        agentOptions.rootKey = Uint8Array.from(
          rootKeyRaw.match(/.{2}/g), (b) => parseInt(b, 16),
        );
      } else {
        agentOptions.rootKey = Uint8Array.from(atob(rootKeyRaw), (c) => c.charCodeAt(0));
      }
    }
    const agent = await HttpAgent.create(agentOptions);
    const escrow = Actor.createActor(idlFactory, { agent, canisterId: escrowId });
    const t = await escrow.getTrustInfo();

    document.getElementById("live").innerHTML = `
      <table>
        ${row("Escrow canister", escrowId)}
        ${row("Version", t.version)}
        ${row("Fee formula", t.feeFormula)}
        ${row("Fee", `${t.feeBps} bps (${Number(t.feeBps) / 100}%)`)}
        ${row("Burn share of fee", `${t.burnSharePct}%`)}
        ${row("Ledger", t.ledgerId.toText())}
        ${row("Job size", `${icp(t.minJobGrossE8s)} – ${icp(t.opCapE8s)} (operational cap)`)}
        ${row("Bonds (client / agent)", `${icp(t.clientJobBondE8s)} / ${icp(t.agentJobBondE8s)}`)}
        ${row("Review window", hours(t.reviewWindowNs))}
        ${row("Receipts settled", `${t.receiptsCount}`)}
        ${row("Total gross settled", icp(t.totalGrossSettledE8s))}
        ${row("Total net paid to agents", icp(t.totalNetPaidE8s))}
        ${row("SQR buyback-and-burn reserve", icp(t.burnReserveE8s))}
        ${row("Treasury reserve", icp(t.treasuryReserveE8s))}
      </table>
      <p class="muted">${t.controllersNote}</p>
      <p class="muted">${t.untrustedContentPolicy}</p>`;
    status.textContent = "Live from the escrow canister:";

    const dash = document.getElementById("dashboard-link");
    dash.innerHTML = `Controllers per canister: verify independently on the
      <a href="https://dashboard.internetcomputer.org/canister/${escrowId}"
         rel="noopener noreferrer">IC dashboard (escrow)</a> — a canister cannot
      prove its own controller list.`;
  } catch (err) {
    status.textContent =
      "Live data unavailable (" + (err?.message ?? String(err)) + "). The formula above is compiled into the escrow canister; verify via its candid interface.";
  }
}

main();

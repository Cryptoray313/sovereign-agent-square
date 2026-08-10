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
    // Primary: ic_env cookie. Fallback (cookie blocked by Brave shields / some
    // mobile browsers): the PUBLIC mainnet IDs below — verifiable on the IC
    // dashboard — plus the agent's built-in mainnet root key (no rootKey opt).
    const PUBLIC_IDS = {
      square_escrow: "2f3bf-hyaaa-aaaag-ay57a-cai",
      square_core: "2c2hr-kaaaa-aaaag-ay57q-cai",
      frontend_assets: "nywey-riaaa-aaaag-ay6aa-cai",
      constitution: "n7xcm-4qaaa-aaaag-ay6aq-cai",
    };
    const env = readCanisterEnv();
    const envIds = {};
    if (env) {
      for (const [k, v] of Object.entries(env)) {
        if (k.startsWith("PUBLIC_CANISTER_ID:")) envIds[k.slice("PUBLIC_CANISTER_ID:".length)] = v;
      }
    }
    const usingEnv = !!envIds.square_escrow;
    const ids = usingEnv ? envIds : PUBLIC_IDS;
    const escrowId = ids.square_escrow;
    if (!escrowId) throw new Error("escrow canister id unavailable");

    // Root key from the ic_env cookie when present (on mainnet it equals the
    // built-in key); otherwise no override → the agent's built-in mainnet key.
    const rootKeyRaw = usingEnv ? (env.IC_ROOT_KEY ?? env.ic_root_key) : null;
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

    // All canister IDs (from ic_env or the public fallback), for the table below.
    const canisters = Object.entries(ids).sort();
    const dashUrl = (id) => `https://dashboard.internetcomputer.org/canister/${id}`;
    const canisterRows = canisters
      .map(([name, id]) =>
        row(name, `<a href="${dashUrl(id)}" rel="noopener noreferrer">${id}</a>`))
      .join("");

    document.getElementById("live").innerHTML = `
      <h3>Canister IDs (verify controllers via each dashboard link)</h3>
      <table>${canisterRows}</table>
      <p class="muted">The <code>constitution</code> canister is a reserved ID
      with no code installed yet — its constants deploy in Phase 3 and the
      canister is blackholed (zero controllers) at SNS launch. An empty module
      hash on its dashboard page is expected today.</p>
      <h3>Escrow parameters &amp; totals</h3>
      <table>
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
        ${row("SQR buyback-and-burn reserve", `${icp(t.burnReserveE8s)} <span class="muted">(self-reported pending Phase 3 sub-account split)</span>`)}
        ${row("Treasury reserve", `${icp(t.treasuryReserveE8s)} <span class="muted">(self-reported pending Phase 3 sub-account split)</span>`)}
      </table>
      <p class="muted">Sample any receipt yourself: call
      <code>getReceipt (jobId)</code> on the escrow via the
      <a href="https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=${escrowId}"
         rel="noopener noreferrer">candid UI</a> — e.g. jobId 0 is the first
      settled job.</p>
      <p class="muted">${t.controllersNote}</p>
      <p class="muted">${t.untrustedContentPolicy}</p>`;
    status.textContent = "Live from the escrow canister:";

    const dash = document.getElementById("dashboard-link");
    dash.innerHTML = `Controllers per canister: verify independently via the
      dashboard links above — a canister cannot prove its own controller list,
      and "who holds zero keys" is only ever provable negatively from those
      controller lists. Who can do what, and until when:
      <a href="./trust.md" rel="noopener noreferrer">TRUST.md</a> (served from
      this canister).`;
  } catch (err) {
    status.textContent =
      "Live data unavailable (" + (err?.message ?? String(err)) + "). The formula above is compiled into the escrow canister; verify via its candid interface.";
  }
}

main();

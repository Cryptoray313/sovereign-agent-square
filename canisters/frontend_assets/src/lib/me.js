// #/me — Phase A payout routing + non-custodial cash-out. Two value-moving
// flows, each behind an explicit confirm screen (destination shown in full,
// never prefilled). SAS never custodies funds: the operator's own agent key
// signs, and cash-out is a direct icrc1_transfer (no approve, no sweep account).
import { loadStoredIdentity, getMeta } from "./identity.js";
import { loadMe, setPayoutAccount, cashOut } from "./data.js";
import { opsBadgeHtml } from "./ops.js";
import { esc, icp } from "./ui.js";
import { Principal } from "./ic.js";

const state = {
  loaded: false, identity: null, principal: null, handle: null,
  stats: null, balanceE8s: 0n, feeE8s: 0n, error: null,
  // payout (Flow 1)
  payoutInput: "", payoutConfirm: false, payoutBusy: false, payoutSubmitted: null,
  // cash-out (Flow 2)
  cashDest: "", cashAmount: "", cashConfirm: false, cashBusy: false, cashDone: null,
};

function app() { return document.getElementById("app"); }

// "0.5" ICP -> 50000000n e8s, or null if malformed.
function parseIcpToE8s(s) {
  const t = (s || "").trim();
  if (!/^\d+(\.\d{1,8})?$/.test(t)) return null;
  const [whole, frac = ""] = t.split(".");
  return BigInt(whole) * 100000000n + BigInt((frac + "00000000").slice(0, 8));
}
function validPrincipal(s) {
  try { Principal.fromText((s || "").trim()); return true; } catch { return false; }
}

export async function renderMe() {
  if (!state.loaded) {
    try {
      const id = await loadStoredIdentity();
      if (id) {
        state.identity = id;
        state.principal = id.getPrincipal().toText();
        state.handle = getMeta().handle || null;
      }
    } catch (_) { /* none */ }
    state.loaded = true;
  }
  if (!state.identity) {
    app().innerHTML = `
      <h2>My agent</h2>
      <div class="card">
        <p>No agent is connected in this browser.</p>
        <a class="cta" href="#/connect">Connect an agent →</a>
      </div>`;
    return;
  }
  await refresh();
  render();
}

async function refresh() {
  try {
    const m = await loadMe(state.principal);
    state.stats = m.stats; state.balanceE8s = m.balanceE8s; state.feeE8s = m.feeE8s;
  } catch (e) { state.error = e?.message ?? String(e); }
}

function render() {
  app().innerHTML = `<div class="wizard">
    ${state.error ? `<div class="errbox">${esc(state.error)}</div>` : ""}
    <h2>My agent ${opsBadgeHtml(state.principal)}</h2>
    ${p0Copy()}
    ${identityCard()}
    ${earningsCard()}
    ${payoutCard()}
    ${cashoutCard()}
  </div>`;
  wire();
}

// P0 expectation copy — verbatim.
function p0Copy() {
  return `<div class="untrusted" role="note" style="border-left-color:var(--ops);background:var(--ops-bg)">
    🪪 <strong>A work badge, not a savings wallet — SAS never custodies a
    withdrawable balance.</strong> Your funds live in your agent's own ledger
    account, controlled by your key on this device. You route future nets and
    cash out yourself; SAS never holds or can move your money.
  </div>`;
}

function identityCard() {
  return `<div class="card">
    <table>
      <tr><td>Handle</td><td><code>${esc(state.handle || "—")}</code></td></tr>
      <tr><td>Principal</td><td><code class="wrap">${esc(state.principal)}</code></td></tr>
    </table>
  </div>`;
}

function earningsCard() {
  const s = state.stats;
  return `<div class="card">
    <h3>Earnings &amp; balance</h3>
    <table>
      <tr><td>Withdrawable balance <span class="muted">(live)</span></td><td><code>${icp(state.balanceE8s)}</code></td></tr>
      <tr><td>Completed jobs</td><td><code>${s ? s.completedJobs : "—"}</code></td></tr>
      <tr><td>Lifetime gross earned</td><td><code>${s ? icp(s.grossEarnedE8s) : "—"}</code></td></tr>
      <tr><td>Lifetime net earned</td><td><code>${s ? icp(s.netEarnedE8s) : "—"}</code></td></tr>
    </table>
    <p class="muted">Lifetime net earned is <strong>historical and cumulative</strong>
      (from receipts). Your <strong>withdrawable balance is the live ledger balance</strong>
      of this agent and will differ — it excludes nets already routed to your payout
      destination or cashed out, and includes any leftover bond funds. They are not
      meant to match; you aren't being shorted.</p>
  </div>`;
}

// ---------- Flow 1: setPayoutAccount ----------
function payoutCard() {
  if (state.payoutConfirm) {
    const dest = state.payoutInput.trim();
    return `<div class="card">
      <h3>Confirm payout destination</h3>
      <p>Set your agent's payout destination to:</p>
      <p><code class="wrap">${esc(dest)}</code></p>
      <div class="untrusted" role="note">⚠️ Future job nets will be paid to this
        address <strong>permanently, until you change it</strong>. <strong>Past
        receipts are unchanged.</strong> SAS does not custody your funds — this only
        tells the escrow where to send your future nets.</div>
      <button id="payout-set" class="cta" ${state.payoutBusy ? "disabled" : ""}>
        ${state.payoutBusy ? "Setting…" : "Set payout destination"}</button>
      <button id="payout-cancel" class="cta ghost">Cancel</button>
    </div>`;
  }
  const submitted = state.payoutSubmitted
    ? `<p class="muted">✓ Last submitted from this browser:
        <code class="wrap">${esc(state.payoutSubmitted)}</code>. The escrow doesn't
        expose a read of the stored value, so this reflects your last successful
        submission here, not a live read.</p>`
    : "";
  return `<div class="card">
    <h3>Payout destination</h3>
    <p class="muted">Where the escrow sends your <strong>future</strong> job nets.
      The escrow provides no read of the current setting, so we can't display it —
      this sets it going forward.</p>
    ${submitted}
    <label class="fieldlabel">Destination principal</label>
    <input id="payout-input" class="filter" type="text" placeholder="paste your wallet principal"
           value="${esc(state.payoutInput)}" autocomplete="off" />
    <button id="payout-review" class="cta">Review →</button>
  </div>`;
}

// ---------- Flow 2: cash-out ----------
function cashoutCard() {
  const bal = state.balanceE8s, fee = state.feeE8s;
  const tooLow = bal <= fee;

  if (state.cashDone) {
    return `<div class="card">
      <h3>Cash out</h3>
      <p>✓ Sent <code>${icp(state.cashDone.amount)}</code> to
        <code class="wrap">${esc(state.cashDone.dest)}</code> — ledger block
        <code>#${state.cashDone.block}</code>.</p>
      <button id="cash-again" class="cta ghost">Cash out again</button>
    </div>`;
  }

  if (state.cashConfirm) {
    const dest = state.cashDest.trim();
    const amt = parseIcpToE8s(state.cashAmount);
    return `<div class="card">
      <h3>Confirm cash-out</h3>
      <table>
        <tr><td>Amount</td><td><code>${icp(amt)}</code></td></tr>
        <tr><td>Network fee</td><td><code>${icp(fee)}</code></td></tr>
        <tr class="net"><td><strong>Total debited</strong></td><td><code><strong>${icp(amt + fee)}</strong></code></td></tr>
        <tr><td>To</td><td><code class="wrap">${esc(dest)}</code></td></tr>
      </table>
      <div class="untrusted" role="note">⚠️ Signed by your agent key. This transfer
        is <strong>irreversible</strong>. SAS is not involved and cannot reverse it.</div>
      <button id="cash-send" class="cta" ${state.cashBusy ? "disabled" : ""}>
        ${state.cashBusy ? "Sending…" : "Send"}</button>
      <button id="cash-cancel" class="cta ghost">Cancel</button>
    </div>`;
  }

  return `<div class="card">
    <h3>Cash out</h3>
    <p class="muted">Send ICP from your agent's account to any wallet — a direct
      transfer signed by your key. SAS never touches it.</p>
    <table>
      <tr><td>Withdrawable balance</td><td><code>${icp(bal)}</code></td></tr>
      <tr><td>Network fee</td><td><code>${icp(fee)}</code></td></tr>
    </table>
    ${tooLow
      ? `<p class="muted">Balance is at or below the network fee — nothing to cash out yet.</p>`
      : `<label class="fieldlabel">Destination principal</label>
         <input id="cash-dest" class="filter" type="text" placeholder="paste your wallet principal"
                value="${esc(state.cashDest)}" autocomplete="off" />
         <label class="fieldlabel">Amount (ICP) <button id="cash-max" class="copybtn" type="button">max</button></label>
         <input id="cash-amount" class="filter" type="text" inputmode="decimal" placeholder="0.0"
                value="${esc(state.cashAmount)}" autocomplete="off" />
         <button id="cash-review" class="cta">Review cash-out →</button>`}
  </div>`;
}

// ---------- wiring ----------
function wire() {
  state.error = null;
  const on = (id, ev, fn) => { const el = document.getElementById(id); if (el) el.addEventListener(ev, fn); };

  // Flow 1
  on("payout-input", "input", (e) => { state.payoutInput = e.target.value; });
  on("payout-review", "click", () => {
    const dest = state.payoutInput.trim();
    if (!validPrincipal(dest)) { state.error = "That isn't a valid principal. Paste your wallet's principal."; render(); return; }
    state.payoutConfirm = true; render();
  });
  on("payout-cancel", "click", () => { state.payoutConfirm = false; render(); });
  on("payout-set", "click", async () => {
    state.payoutBusy = true; render();
    try {
      const res = await setPayoutAccount(state.identity, state.payoutInput.trim());
      state.payoutBusy = false; state.payoutConfirm = false;
      if (res.ok) { state.payoutSubmitted = state.payoutInput.trim(); state.payoutInput = ""; }
      else state.error = payoutErr(res);
      render();
    } catch (e) { state.payoutBusy = false; state.error = e?.message ?? String(e); render(); }
  });

  // Flow 2
  on("cash-dest", "input", (e) => { state.cashDest = e.target.value; });
  on("cash-amount", "input", (e) => { state.cashAmount = e.target.value; });
  on("cash-max", "click", () => {
    if (state.balanceE8s > state.feeE8s) {
      const max = state.balanceE8s - state.feeE8s;
      state.cashAmount = (Number(max) / 1e8).toString();
      const el = document.getElementById("cash-amount"); if (el) el.value = state.cashAmount;
    }
  });
  on("cash-review", "click", () => {
    const dest = state.cashDest.trim();
    const amt = parseIcpToE8s(state.cashAmount);
    if (!validPrincipal(dest)) { state.error = "Destination isn't a valid principal."; render(); return; }
    if (Principal.fromText(dest).toText() === state.principal) {
      state.error = "That's this agent's own address — choose an external wallet."; render(); return;
    }
    if (amt === null || amt <= 0n) { state.error = "Enter a positive amount."; render(); return; }
    if (amt + state.feeE8s > state.balanceE8s) {
      state.error = "Amount plus fee exceeds your balance."; render(); return;
    }
    state.cashConfirm = true; render();
  });
  on("cash-cancel", "click", () => { state.cashConfirm = false; render(); });
  on("cash-send", "click", async () => {
    state.cashBusy = true; render();
    const amt = parseIcpToE8s(state.cashAmount);
    const dest = state.cashDest.trim();
    try {
      const res = await cashOut(state.identity, dest, amt, state.feeE8s);
      state.cashBusy = false; state.cashConfirm = false;
      if (res.ok) {
        state.cashDone = { amount: amt, dest, block: res.block };
        state.cashDest = ""; state.cashAmount = "";
        await refresh();
      } else {
        state.error = cashErr(res);
      }
      render();
    } catch (e) { state.cashBusy = false; state.error = e?.message ?? String(e); render(); }
  });
  on("cash-again", "click", async () => { state.cashDone = null; await refresh(); render(); });
}

function payoutErr(res) {
  switch (res.error) {
    case "anonymousCaller": return "Your agent identity wasn't loaded — reload and try again.";
    case "invalidInput": return `Rejected: ${res.detail || "invalid destination."}`;
    case "notAuthorized": return "Not authorized to set this payout account.";
    case "locked": return "The escrow is briefly locked — try again in a moment.";
    case "ledgerError": return `Ledger error: ${res.detail || ""}`;
    default: return `Couldn't set payout destination (${res.error}).`;
  }
}
function cashErr(res) {
  switch (res.error) {
    case "InsufficientFunds": return `Insufficient funds (balance ${res.detail ? icp(BigInt(res.detail.balance)) : "?"}).`;
    case "BadFee": return `Fee changed — reopen the page to refresh the fee and retry.`;
    case "TooOld": case "CreatedInFuture": return "Timing issue with the ledger — retry.";
    case "TemporarilyUnavailable": return "Ledger temporarily unavailable — retry shortly.";
    case "Duplicate": return "This looks like a duplicate of a recent transfer.";
    case "GenericError": return `Ledger error: ${res.detail?.message || ""}`;
    default: return `Transfer failed (${res.error}).`;
  }
}

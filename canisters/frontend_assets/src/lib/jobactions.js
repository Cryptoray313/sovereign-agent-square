// C3a Bid + C3c Deliver — agent actions on a job detail. Both are low-risk:
// bid(jobId) and deliver(jobId, hash) are agent-key-signed with NO payment. The
// bond/allowance (icrc2_approve) belongs to C3b (accept), which is held.
// Reuses the C1 connected identity (IndexedDB). Rendered into #job-actions so
// re-renders don't disturb the rest of the job detail (incl. the spec banner).
import { loadStoredIdentity, getMeta } from "./identity.js";
import { placeBid, deliverWork } from "./data.js";
import { esc, icp } from "./ui.js";
import { toHex } from "./format.js";

const st = {
  job: null, principal: null, handle: null,
  mode: "idle",            // idle | bid-confirm | deliver-input | deliver-confirm
  busy: false, error: null,
  deliverText: "", deliverFileName: null, hashBytes: null, hashHex: null,
  bidPlaced: false,
};

function el() { return document.getElementById("job-actions"); }

// client-side bid tracking (chain exposes no bidders list) — per principal.
function bidKey(p) { return `sas.bids.${p}`; }
function hasBid(p, jobId) {
  try { return (JSON.parse(localStorage.getItem(bidKey(p)) || "[]")).includes(jobId); } catch { return false; }
}
function markBid(p, jobId) {
  try {
    const a = JSON.parse(localStorage.getItem(bidKey(p)) || "[]");
    if (!a.includes(jobId)) a.push(jobId);
    localStorage.setItem(bidKey(p), JSON.stringify(a));
  } catch (_) {}
}

async function sha256(bytes) {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
}

export async function mountJobActions(job) {
  Object.assign(st, {
    job, principal: null, handle: null, mode: "idle", busy: false, error: null,
    deliverText: "", deliverFileName: null, hashBytes: null, hashHex: null, bidPlaced: false,
  });
  try {
    const id = await loadStoredIdentity();
    if (id) { st.principal = id.getPrincipal().toText(); st.handle = getMeta().handle || null; st.identity = id; }
  } catch (_) { /* none */ }
  render();
}

function render() {
  const c = el(); if (!c) return;
  c.innerHTML = `${st.error ? `<div class="errbox">${esc(st.error)}</div>` : ""}${body()}`;
  wire();
}

function body() {
  const j = st.job;
  // Not connected → prompt to connect.
  if (!st.principal) {
    return `<div class="card"><h3>Bid on this job</h3>
      <p class="muted">Connect an agent to bid.</p>
      <a class="cta" href="#/connect">Connect an agent →</a></div>`;
  }
  // Own job — can't bid on it.
  if (j.client === st.principal) {
    return `<div class="card"><h3>Your job</h3>
      <p class="muted">You posted this job, so you can't bid on it.</p></div>`;
  }
  const isMine = j.agent === st.principal || j.selectedAgent === st.principal;

  // BID (C3a) — only while open.
  if (j.status === "open") {
    if (st.bidPlaced || hasBid(st.principal, j.id)) {
      return `<div class="card"><h3>Bid</h3>
        <button class="cta" disabled>Bid placed ✓</button>
        <p class="muted">Your agent has bid on this job. If the client selects you,
          you'll accept and post a bond next (coming soon).</p></div>`;
    }
    if (st.mode === "bid-confirm") {
      return `<div class="card"><h3>Confirm bid</h3>
        <table>
          <tr><td>Job</td><td><code>#${j.id}</code></td></tr>
          <tr><td>Gross</td><td><code>${icp(j.grossE8s)}</code></td></tr>
          <tr><td>Signing as</td><td><code class="wrap">${esc(st.principal)}</code></td></tr>
        </table>
        <p class="muted">Bidding is free and posts no bond. A bond is only posted if
          the client selects you and you accept (coming soon).</p>
        <button id="bid-go" class="cta" ${st.busy ? "disabled" : ""}>${st.busy ? "Bidding…" : "Place bid"}</button>
        <button id="bid-cancel" class="cta ghost">Cancel</button></div>`;
    }
    return `<div class="card"><h3>Bid on this job</h3>
      <p class="muted">Bid as <code>${esc(st.handle || "your agent")}</code>. Free, no bond.</p>
      <button id="bid-start" class="cta">Bid with my agent</button></div>`;
  }

  // DELIVER (C3c) — only when assigned to me.
  if (j.status === "assigned" && isMine) {
    if (st.mode === "deliver-confirm") {
      return `<div class="card"><h3>Confirm delivery</h3>
        <p>Submit this deliverable hash for <strong>Job #${j.id}</strong>:</p>
        <p><code class="wrap">${esc(st.hashHex)}</code></p>
        <p class="muted">Only the SHA-256 hash goes on-chain — your deliverable content
          stays with you and the client, off-chain. Make sure it's the final version.</p>
        <button id="dlv-go" class="cta" ${st.busy ? "disabled" : ""}>${st.busy ? "Submitting…" : "Submit delivery"}</button>
        <button id="dlv-cancel" class="cta ghost">Back</button></div>`;
    }
    return `<div class="card"><h3>Deliver your work</h3>
      <p class="muted">Paste the deliverable text or attach the file. We hash it in your
        browser (SHA-256) and submit only the hash — the content never leaves your device.</p>
      <label class="fieldlabel">Deliverable text</label>
      <textarea id="dlv-text" class="filter" rows="4" placeholder="Paste your deliverable…">${esc(st.deliverText)}</textarea>
      <label class="fieldlabel">…or a file <span class="muted">${st.deliverFileName ? "(" + esc(st.deliverFileName) + ")" : ""}</span></label>
      <input id="dlv-file" type="file" class="filter" />
      <button id="dlv-review" class="cta">Hash &amp; review →</button></div>`;
  }

  // Post-delivery / completed states for my assignment.
  if (isMine && j.status === "delivered") {
    return `<div class="card"><h3>Delivered ✓</h3>
      <p>Your delivery is in. The client has <strong>72 hours</strong> to review and
        accept; on acceptance (or timeout in your favor) your net is paid out.</p></div>`;
  }
  if (isMine && (j.status === "released")) {
    return `<div class="card"><h3>Completed ✓</h3>
      <p>This job settled. <a href="#/receipts">See it in the receipts explorer →</a></p></div>`;
  }

  // Connected, but nothing to do here (job not open, not mine).
  return `<div class="card"><h3>Actions</h3>
    <p class="muted">This job isn't open for bids${isMine ? "" : " and isn't assigned to your agent"}.</p></div>`;
}

function wire() {
  st.error = null;
  const on = (id, ev, fn) => { const e = document.getElementById(id); if (e) e.addEventListener(ev, fn); };
  const j = st.job;

  // Bid
  on("bid-start", "click", () => { st.mode = "bid-confirm"; render(); });
  on("bid-cancel", "click", () => { st.mode = "idle"; render(); });
  on("bid-go", "click", async () => {
    st.busy = true; render();
    try {
      const res = await placeBid(st.identity, j.id);
      st.busy = false;
      if (res.ok) { markBid(st.principal, j.id); st.bidPlaced = true; st.mode = "idle"; }
      else if (res.error === "wrongStatus") { st.error = "This job is no longer open for bids."; st.mode = "idle"; }
      else st.error = bidErr(res);
      render();
    } catch (e) { st.busy = false; st.error = e?.message ?? String(e); render(); }
  });

  // Deliver
  on("dlv-text", "input", (e) => { st.deliverText = e.target.value; });
  on("dlv-file", "change", (e) => { st.deliverFileName = e.target.files?.[0]?.name || null; });
  on("dlv-review", "click", async () => {
    try {
      const file = document.getElementById("dlv-file")?.files?.[0];
      let bytes;
      if (file) bytes = new Uint8Array(await file.arrayBuffer());
      else if (st.deliverText.trim()) bytes = new TextEncoder().encode(st.deliverText);
      else { st.error = "Paste deliverable text or choose a file first."; render(); return; }
      st.hashBytes = await sha256(bytes);
      st.hashHex = toHex(st.hashBytes);
      st.mode = "deliver-confirm"; render();
    } catch (e) { st.error = e?.message ?? String(e); render(); }
  });
  on("dlv-cancel", "click", () => { st.mode = "deliver-input"; render(); });
  on("dlv-go", "click", async () => {
    st.busy = true; render();
    try {
      const res = await deliverWork(st.identity, j.id, st.hashBytes);
      st.busy = false;
      if (res.ok) { j.status = "delivered"; st.mode = "idle"; }
      else st.error = deliverErr(res);
      render();
    } catch (e) { st.busy = false; st.error = e?.message ?? String(e); render(); }
  });
}

function bidErr(res) {
  switch (res.error) {
    case "anonymousCaller": return "Your agent identity wasn't loaded — reload and try again.";
    case "notFound": return "This job no longer exists.";
    case "invalidInput": return `Bid rejected: ${res.detail || ""}`;
    case "locked": return "The escrow is briefly locked — try again in a moment.";
    default: return `Bid failed (${res.error}).`;
  }
}
function deliverErr(res) {
  switch (res.error) {
    case "wrongStatus": return "This job isn't in a deliverable state (it must be assigned to you).";
    case "notAuthorized": return "Only the assigned agent can deliver this job.";
    case "invalidInput": return `Delivery rejected: ${res.detail || ""}`;
    default: return `Delivery failed (${res.error}).`;
  }
}

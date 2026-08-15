// Sovereign Agent Square — human site. Read surfaces are view-only; the Connect
// wizard adds exactly ONE on-chain write (square_core.register). No admin chrome,
// no withdraw, no spending. Canister IDs read from trust config (ic_env).
// Self-contained bundle (esbuild).
import {
  loadPulse, loadMarket, loadJob, loadAgent, previewSplit, clientRepFromMarket,
} from "./lib/data.js";
import { renderConnect } from "./lib/connect.js";
import { renderMe } from "./lib/me.js";
import { mountJobActions } from "./lib/jobactions.js";
import {
  esc, icp, shortPrincipal, isoDate, timeAgo, nsHours,
  untrustedBanner, statusPill, principalLink, skillsHtml, economicsCard,
  loading, errorBox, NET_FORMULA,
} from "./lib/ui.js";
import { opsBadgeHtml, opsLabel, externalLabel } from "./lib/ops.js";
import { startRain, countUp } from "./lib/square.js";

// Compact three-state badge for tight storefront rows: same classification as
// opsBadgeHtml (ops-test / external / unlabeled), full registry label in the
// tooltip instead of inline.
function opsBadgeShort(p) {
  const o = opsLabel(p);
  if (o) return `<span class="badge ops" title="${esc(`ops-test · ${o}`)}">ops-test</span>`;
  const e = externalLabel(p);
  if (e) return `<span class="badge ok" title="${esc(`external · ${e}`)}">external</span>`;
  return `<span class="badge ext" title="Not in the ops-test or external registry — unaccounted; treat as external until verified">unlabeled</span>`;
}

const app = () => document.getElementById("app");

// ---------- router ----------
function parseRoute() {
  const h = location.hash.replace(/^#/, "") || "/";
  const parts = h.split("/").filter(Boolean); // e.g. ["jobs","3"]
  return { path: "/" + parts.join("/"), parts };
}

const routes = [
  { re: /^\/$/, view: renderHome },
  { re: /^\/jobs$/, view: renderJobs },
  { re: /^\/jobs\/(\d+)$/, view: (m) => renderJobDetail(m[1]) },
  { re: /^\/receipts$/, view: renderReceipts },
  { re: /^\/agents\/([^/]+)$/, view: (m) => renderAgent(decodeURIComponent(m[1])) },
  { re: /^\/connect$/, view: renderConnect },
  { re: /^\/me$/, view: renderMe },
];

async function router() {
  const { path } = parseRoute();
  setActiveNav(path);
  const container = app();
  container.innerHTML = loading("Loading");
  for (const r of routes) {
    const m = path.match(r.re);
    if (m) {
      try { await r.view(m); }
      catch (e) { container.innerHTML = errorBox(e?.message ?? String(e)); }
      window.scrollTo(0, 0);
      return;
    }
  }
  container.innerHTML = `<div class="card"><h2>Not found</h2>
    <p class="muted">No such page. <a href="#/">Back to home</a>.</p></div>`;
}

function setActiveNav(path) {
  const top = "/" + (path.split("/")[1] || "");
  document.querySelectorAll("nav.top a[data-route]").forEach((a) => {
    a.classList.toggle("active", a.getAttribute("data-route") === top);
  });
}

// ---------- home: the town square (packet-4 skyline, live data only) ----------
async function renderHome() {
  const p = await loadPulse();
  // Honesty banner derived from live per-receipt verification (never assumed).
  const N = p.receiptsLoaded;
  const extPill = `<span class="extcount">external count: ${p.externalReceipts}</span>`;
  const opsNote = p.unlabelledReceipts === 0
    ? `<div class="opsbanner">
        ${extPill}
        <strong>Everything you see here is ops-test.</strong> All
        <strong>${N} of ${N}</strong> settled receipts come from
        ${p.distinctOps} internal operator account${p.distinctOps === 1 ? "" : "s"} —
        <em>not</em> organic adoption. Every operator principal is badged
        <span class="badge ops">ops-test</span> wherever it appears. We verify this
        per-receipt on every load and publish it on purpose: honesty over impressive numbers.
      </div>`
    : `<div class="opsbanner" style="border-left-color:var(--ext);background:var(--ext-bg)">
        ${extPill}
        <strong>⚠️ ${p.unlabelledReceipts} of ${N} receipts involve a principal NOT in the
        ops-test registry.</strong> ${p.opsReceipts} are ops-test (${p.distinctOps} internal
        accounts). The remainder may be <strong>external participants</strong> — they appear
        <span class="badge ext">unlabeled</span> on the
        <a href="#/receipts">receipts</a> page. This has not been reconciled; treat with care.
      </div>`;

  // The four signs — locked names, existing routes only.
  const skyline = `<div class="skyline">
    <a class="bb bb1" href="#/jobs"><span class="n">01</span><span class="v">Read spec</span><span class="r">/jobs</span></a>
    <a class="bb bb2" href="./trust.html"><span class="n">02</span><span class="v">Verify</span><span class="r">/trust</span></a>
    <a class="bb bb3" href="#/connect"><span class="n">03</span><span class="v">Bid</span><span class="r">/connect</span></a>
    <a class="bb bb4" href="#/receipts"><span class="n">04</span><span class="v">Get paid</span><span class="r">/receipts</span></a>
  </div>`;

  // Storefronts: LIVE open jobs (same data + claims as the board), plus browse-all.
  const open = p.market.jobs.filter((j) => j.status === "open");
  const front = open.slice(0, 5);
  const splits = await Promise.all(front.map((j) => previewSplit(j.grossE8s)));
  const stores = front.map((j, i) => {
    const estNet = splits[i].agentNetE8s - j.ledgerFeeE8s;
    return `<a class="store" href="#/jobs/${j.id}">
      <div class="jhead"><b>Job #${j.id}</b>${statusPill(j.status)}</div>
      <div>${skillsHtml(j.skills)}</div>
      <div class="jrow"><span>Gross</span><code>${icp(j.grossE8s)}</code></div>
      <div class="jrow"><span>Est. net</span><code>${icp(estNet)}</code></div>
      <div class="jrow"><span>Client</span><span><code>${shortPrincipal(j.client)}</code> ${opsBadgeShort(j.client)}</span></div>
    </a>`;
  }).join("");
  const browseAll = `<a class="store browseall" href="#/jobs">
    <div><b style="color:var(--accent)">Browse all jobs →</b>
    <div class="muted" style="margin-top:0.2rem">open board, live from escrow</div></div></a>`;

  app().innerHTML = `
    <section class="hero">
      <canvas id="rain"></canvas>
      <div class="inner">
        ${skyline}
        <div class="squarecta">
          <span class="line">Bring your agent. Pick a job. <span class="g">Come get paid.</span></span>
          <a class="btn primary" href="#/jobs">Browse jobs →</a>
          <a class="btn ghost" href="#/connect">Connect an agent</a>
        </div>
        <div class="rail">
          <span class="dot"></span>
          <span class="stat"><b id="rail-open">0</b><span>open</span></span>
          <span class="sep">·</span>
          <span class="stat"><b id="rail-escrowed">0.00</b><span>ICP escrowed</span></span>
          <span class="sep">·</span>
          <span class="stat"><b id="rail-receipts">0</b><span>receipts</span></span>
          <span class="sep">·</span>
          <span class="live">live · loadPulse()</span>
        </div>
      </div>
    </section>
    ${opsNote}
    <h2 class="sec">Open <b>storefronts</b> <span class="muted" style="text-transform:none;letter-spacing:0">· live from escrow</span></h2>
    <div class="stores">${stores}${browseAll}</div>
    <p class="formula muted"><code>${esc(NET_FORMULA)}</code></p>`;

  // Motion: rain behind the hero only; rail numbers count up to the LIVE
  // values from loadPulse (static under prefers-reduced-motion).
  startRain(document.getElementById("rain"));
  countUp(document.getElementById("rail-open"), p.openCount);
  countUp(document.getElementById("rail-escrowed"), Number(p.escrowedE8s) / 1e8, { decimals: 2 });
  countUp(document.getElementById("rail-receipts"), p.receiptsCount);
}

// ---------- jobs board ----------
async function renderJobs() {
  const market = await loadMarket();
  const open = market.jobs.filter((j) => j.status === "open");

  if (!open.length) {
    app().innerHTML = `
      <h2>Job board</h2>
      <div class="opsbanner">The board shows <strong>open</strong> jobs awaiting an agent.
        There are none right now. All ${market.receipts.length} jobs to date have already
        settled — see <a href="#/receipts">receipts</a>. (Everything to date is
        <span class="badge ops">ops-test</span>.)</div>`;
    return;
  }

  // Estimated agent net per open job (previewSplit is authoritative on the split).
  const splits = await Promise.all(open.map((j) => previewSplit(j.grossE8s)));
  const rows = open.map((j, i) => {
    const s = splits[i];
    const estNet = s.agentNetE8s - j.ledgerFeeE8s;
    const clientRep = clientRepFromMarket(market, j.client);
    return `<div class="card job" data-skills="${esc(j.skills.join(" ").toLowerCase())}">
      <div class="jhead">
        <a href="#/jobs/${j.id}"><strong>Job #${j.id}</strong></a>
        ${statusPill(j.status)}
      </div>
      <div class="jskills">${skillsHtml(j.skills)}</div>
      <table>
        <tr><td>Gross</td><td><code>${icp(j.grossE8s)}</code></td></tr>
        <tr><td>Est. agent net</td><td><code>${icp(estNet)}</code></td></tr>
        <tr><td>Deadline</td><td><code>${timeAgo(j.deadlineNs)}</code> <span class="muted">(${isoDate(j.deadlineNs)})</span></td></tr>
        <tr><td>Client</td><td>${principalLink(j.client)} <span class="muted">${clientRep} settled as client</span></td></tr>
      </table>
      <a class="more" href="#/jobs/${j.id}">View job →</a>
    </div>`;
  }).join("");

  app().innerHTML = `
    <h2>Job board <span class="muted">(${open.length} open)</span></h2>
    <input id="skillfilter" class="filter" type="text" placeholder="Filter by skill…" autocomplete="off" />
    <p class="formula"><code>${esc(NET_FORMULA)}</code></p>
    <div id="joblist">${rows}</div>`;

  const f = document.getElementById("skillfilter");
  f.addEventListener("input", () => {
    const q = f.value.trim().toLowerCase();
    document.querySelectorAll("#joblist .job").forEach((el) => {
      el.style.display = !q || el.dataset.skills.includes(q) ? "" : "none";
    });
  });
}

// ---------- job detail ----------
// Content-addressed fetch: any job's spec bytes live at /specs/by-hash/<hash>.md
// when published. The re-hash below is defense in depth — bytes are verified
// against the ON-CHAIN specHash even though the URL already names the hash.
async function verifySpec(specHashHex) {
  try {
    const res = await fetch(`./specs/by-hash/${specHashHex}.md`);
    if (!res.ok) return null;
    const buf = await res.arrayBuffer();
    const digest = await crypto.subtle.digest("SHA-256", buf);
    const hex = Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
    const text = new TextDecoder().decode(buf);
    return { text, matches: hex === specHashHex, computed: hex };
  } catch { return null; }
}

async function renderJobDetail(idStr) {
  const id = Number(idStr);
  const { job, receipt } = await loadJob(id);
  if (!job) {
    app().innerHTML = `<div class="card"><h2>Job #${esc(idStr)}</h2>
      <p class="muted">No such job. <a href="#/jobs">Back to board</a>.</p></div>`;
    return;
  }

  // Economics: actual receipt if settled, else estimate.
  let econ;
  if (receipt) {
    econ = {
      grossE8s: receipt.grossE8s, feeE8s: receipt.feeE8s,
      burnE8s: receipt.burnOrEarmarkE8s, treasuryE8s: receipt.treasuryE8s,
      ledgerFeeE8s: job.ledgerFeeE8s, netE8s: receipt.netE8s,
      clientBondE8s: job.clientBondE8s, agentBondE8s: job.agentBondE8s,
      estimated: false,
    };
  } else {
    const s = await previewSplit(job.grossE8s);
    econ = {
      grossE8s: s.grossE8s, feeE8s: s.feeE8s,
      burnE8s: s.burnPathE8s, treasuryE8s: s.treasuryE8s,
      ledgerFeeE8s: job.ledgerFeeE8s, netE8s: s.agentNetE8s - job.ledgerFeeE8s,
      clientBondE8s: job.clientBondE8s, agentBondE8s: job.agentBondE8s,
      estimated: true,
    };
  }

  const spec = await verifySpec(job.specHashHex);
  let specBlock;
  if (spec) {
    const verdict = spec.matches
      ? `<span class="badge ok">✓ hash matches chain</span>`
      : `<span class="badge ext">✗ hash mismatch — do not trust</span>`;
    specBlock = `
      <h3>Spec ${verdict}</h3>
      ${untrustedBanner("This job specification")}
      ${spec.matches ? `<pre class="spec">${esc(spec.text)}</pre>` : ``}
      <p class="muted">On-chain specHash: <code>${esc(job.specHashHex)}</code></p>`;
  } else {
    specBlock = `
      <h3>Spec <span class="badge ext">bytes not published</span></h3>
      <p><strong>Spec hash committed; bytes not published — do not work this
      job.</strong> The client committed only the hash on-chain; until the
      byte-exact spec is published (here content-addressed, or by the client
      elsewhere) an agent cannot read what the job asks, so bidding on it is
      working blind.</p>
      <p class="muted">On-chain specHash:</p>
      <p><code class="wrap">${esc(job.specHashHex)}</code></p>`;
  }

  const agentRow = job.agent
    ? `<tr><td>Agent</td><td>${principalLink(job.agent)}</td></tr>` : "";
  const deliverRow = job.payloadHashHex
    ? `<tr><td>Deliverable hash</td><td><code class="wrap">${esc(job.payloadHashHex)}</code></td></tr>` : "";

  app().innerHTML = `
    <p><a href="#/jobs">← board</a></p>
    <h2>Job #${job.id} ${statusPill(job.status)}</h2>
    <div class="card">
      <div class="jskills">${skillsHtml(job.skills)}</div>
      <table>
        <tr><td>Client</td><td>${principalLink(job.client)}</td></tr>
        ${agentRow}
        <tr><td>Created</td><td><code>${isoDate(job.createdAtNs)}</code> <span class="muted">(${timeAgo(job.createdAtNs)})</span></td></tr>
        <tr><td>Deadline</td><td><code>${isoDate(job.deadlineNs)}</code> <span class="muted">(${timeAgo(job.deadlineNs)})</span></td></tr>
        ${job.deliveredAtNs ? `<tr><td>Delivered</td><td><code>${isoDate(job.deliveredAtNs)}</code></td></tr>` : ""}
        ${deliverRow}
      </table>
    </div>
    <div id="job-actions"></div>
    ${economicsCard(econ)}
    <div class="card">${specBlock}</div>
    ${receipt ? `<p><a href="#/receipts">See this in the receipts explorer →</a></p>` : ""}`;

  // Bid (C3a) / Deliver (C3c) actions — mounted into #job-actions so its own
  // re-renders don't disturb the spec/economics above.
  mountJobActions(job);
}

// ---------- receipts ----------
async function renderReceipts() {
  const market = await loadMarket();
  const rs = market.receipts;
  const opsAll = rs.every((r) => opsBadgeHtml(r.client).includes("ops-test") && opsBadgeHtml(r.agent).includes("ops-test"));

  const rows = rs.map((r) => `
    <div class="card receipt" data-q="${esc((r.jobId + " " + r.client + " " + r.agent).toLowerCase())}">
      <div class="jhead">
        <a href="#/jobs/${r.jobId}"><strong>Job #${r.jobId}</strong></a>
        <span class="muted">${timeAgo(r.ts)} · ${isoDate(r.ts)}</span>
      </div>
      <table>
        <tr><td>Client</td><td>${principalLink(r.client)}</td></tr>
        <tr><td>Agent</td><td>${principalLink(r.agent)}</td></tr>
        <tr><td>Gross</td><td><code>${icp(r.grossE8s)}</code></td></tr>
        <tr><td>Fee (5%)</td><td><code>${icp(r.feeE8s)}</code> <span class="muted">(burn ${icp(r.burnOrEarmarkE8s)} / treasury ${icp(r.treasuryE8s)})</span></td></tr>
        <tr class="net"><td><strong>Net to agent</strong></td><td><code><strong>${icp(r.netE8s)}</strong></code></td></tr>
      </table>
    </div>`).join("");

  app().innerHTML = `
    <h2>Receipts <span class="muted">(${rs.length})</span></h2>
    <div class="opsbanner">${opsAll
      ? `All ${rs.length} receipts are <span class="badge ops">ops-test</span> — internal operator accounts, not external adoption.`
      : `Some receipts are unlabelled — see badges below.`}</div>
    <input id="rfilter" class="filter" type="text" placeholder="Filter by job # or principal…" autocomplete="off" />
    <p class="formula"><code>${esc(NET_FORMULA)}</code></p>
    <div id="rlist">${rows}</div>`;

  const f = document.getElementById("rfilter");
  f.addEventListener("input", () => {
    const q = f.value.trim().toLowerCase();
    document.querySelectorAll("#rlist .receipt").forEach((el) => {
      el.style.display = !q || el.dataset.q.includes(q) ? "" : "none";
    });
  });
}

// ---------- agent / participant profile ----------
async function renderAgent(principalStr) {
  const a = await loadAgent(principalStr);
  if (a.error) {
    app().innerHTML = `<div class="card"><h2>Profile</h2>
      <p class="muted">Invalid principal: <code>${esc(principalStr)}</code></p></div>`;
    return;
  }
  const { stats, receipts, profile } = a;

  // A present profile renders ONLY the profile (handle + registered + optional
  // bio). The empty-state text appears solely when getProfile returned none.
  const profileBlock = profile
    ? `<p><span class="handle">${esc(profile.handle)}</span> <span class="muted">· registered ${isoDate(profile.registeredAtNs)}</span></p>` +
      (profile.bio
        ? `${untrustedBanner("This profile bio")}<p class="bio">${esc(profile.bio)}</p>`
        : `<p class="muted">No bio set.</p>`)
    : `<p class="muted">No lobby profile registered for this principal.</p>`;

  const recRows = receipts.length ? receipts.map((r) => `
    <tr>
      <td><a href="#/jobs/${r.jobId}">#${r.jobId}</a></td>
      <td>${principalLink(r.client)}</td>
      <td><code>${icp(r.grossE8s)}</code></td>
      <td><code>${icp(r.netE8s)}</code></td>
      <td class="muted">${timeAgo(r.ts)}</td>
    </tr>`).join("")
    : `<tr><td colspan="5" class="muted">No receipts as agent.</td></tr>`;

  app().innerHTML = `
    <p><a href="#/receipts">← receipts</a></p>
    <h2>Participant ${opsBadgeHtml(principalStr)}</h2>
    <div class="card">
      <p><code class="wrap">${esc(principalStr)}</code></p>
      ${profileBlock}
    </div>
    <div class="card">
      <h3>Reputation <span class="muted">(receipts only)</span></h3>
      <table>
        <tr><td>Completed jobs (as agent)</td><td><code>${stats.completedJobs}</code></td></tr>
        <tr><td>Gross earned</td><td><code>${icp(stats.grossEarnedE8s)}</code></td></tr>
        <tr><td>Net earned</td><td><code>${icp(stats.netEarnedE8s)}</code></td></tr>
        <tr><td>Jobs settled as client</td><td><code>${a.asClientCount}</code></td></tr>
        <tr><td>First / last receipt</td><td><code>${stats.firstReceiptTs ? isoDate(stats.firstReceiptTs) : "—"}</code> / <code>${stats.lastReceiptTs ? isoDate(stats.lastReceiptTs) : "—"}</code></td></tr>
      </table>
    </div>
    <div class="card">
      <h3>Receipts as agent</h3>
      <table class="rtable">
        <tr><th>Job</th><th>Client</th><th>Gross</th><th>Net</th><th>When</th></tr>
        ${recRows}
      </table>
    </div>`;
}

// ---------- boot ----------
window.addEventListener("hashchange", router);
router();

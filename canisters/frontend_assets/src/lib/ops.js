// Ops-test identity registry — HONESTY OVER IMPRESSIVE NUMBERS.
//
// Every principal below is an internal, operator-run account used to exercise
// the market. These are PUBLIC principals only (never seeds). As of the H1
// build, 100% of on-chain receipts (jobs #0–21) map to these identities —
// there is zero external adoption yet, and the site must never let the pulse
// read as organic. Wherever a principal appears in jobs/receipts/profiles we
// badge it "ops-test — not external".
//
// This list is maintained here deliberately: there is no on-chain "ops-test"
// flag, so publishing the mapping IS the honesty mechanism. It is not a
// hardcoded canister ID (those are read from trust config) — it is disclosure.
//
// Two cohorts:
//   • Mac genesis set (ez-*)     — jobs #0–9
//   • Pi-side crew set (sas-*)   — jobs #10–21 (crew-loop handoff §3)
export const OPS_TEST = {
  // Mac genesis (jobs #0–9)
  "ebo7w-zlxul-p2wq5-gmafw-qtsom-hil4z-vxnuu-zorow-fy7lg-aagdc-nae": "ez-client",
  "3cg5u-5v4mc-rj66x-ve4n6-tc53t-t6ein-bb4wy-gzsgm-53f6t-35p2n-qae": "ez-agent-0",
  "hixge-rvkfa-fvoez-m76lt-mtx65-bepgv-za2sa-ay77o-s2v3g-iwbek-zqe": "ez-agent-1",
  // Pi-side crew (jobs #10–21)
  "ncyf6-ltefd-qupda-krywn-qrd7a-hy32r-ivxnm-sofrt-vjfwt-2x32o-4qe": "sas-client",
  "77q4c-6lllv-6mkft-dz3ov-bnnmz-ghadq-juu5k-sc2ky-wv2ud-tiuws-kae": "sas-ledger",
  "nf7y3-uop6k-tt33a-fge27-vux4e-yaixe-3x5gf-f6tyg-sgyy6-qhtm5-kqe": "sas-scribe",
  "v6dfb-l2g4s-524si-ablbl-abjru-xk6dm-ntsmi-i6vfq-4g4a4-j2jbv-yqe": "sas-scout",
  "vcbtl-lflfw-e4m5r-ork4i-fgyhy-fm4y5-ryx4h-sffnh-3pnjo-zcb43-5ae": "sas-warden",
};

export function opsLabel(principalText) {
  return OPS_TEST[principalText] ?? null;
}

export function isOpsTest(principalText) {
  return Object.prototype.hasOwnProperty.call(OPS_TEST, principalText);
}

// Small inline badge. `label` is the internal alias; safe (from our own list).
export function opsBadgeHtml(principalText) {
  const label = opsLabel(principalText);
  if (label) {
    return `<span class="badge ops" title="Internal operator account — not an external participant">ops-test · ${label}</span>`;
  }
  // A principal NOT in the registry that appears in traffic would be genuinely
  // external — surface it plainly rather than silently implying ops-test.
  return `<span class="badge ext" title="Not in the ops-test registry — treat as external until verified">unlabeled</span>`;
}

// How many distinct ops identities exist, for the honesty banner copy.
export const OPS_COUNT = Object.keys(OPS_TEST).length;

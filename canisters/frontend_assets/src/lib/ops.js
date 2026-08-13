// Ops-test identity registry — HONESTY OVER IMPRESSIVE NUMBERS.
//
// The canonical data lives in ops-registry.json (imported below) so that ONE
// source of truth is shared by the UI and the CI honesty guard
// (scripts/ops-reconcile.sh). These are PUBLIC principals only (never seeds).
//
// Two classifications, both DELIBERATE:
//   • opsTest  — internal, operator-run accounts used to exercise the market:
//                Mac genesis (ez-*, jobs #0–9), the Pi-side crew (sas-*, jobs
//                #10+; crew-loop handoff §3), and ops-held test/throwaway keys
//                (cold-start validation runs, the member-0 Connect-wizard test).
//   • external — a genuinely external participant, added by a maintainer only
//                AFTER verifying it is not one of ours. Empty today.
//
// The invariant the CI guard enforces: every principal that appears in an
// on-chain receipt must be classified here (opsTest OR external). An
// unclassified on-chain principal renders as "unlabeled" in the UI AND fails
// the build — so the site can never silently present an unknown as ops-test,
// and drift is caught before publication. The registry may also list ops
// identities with on-chain presence but no receipts (test registrations,
// throwaway keys) so nothing ours ever renders unlabeled. There is no on-chain
// "ops-test" flag; publishing this mapping IS the honesty mechanism. It is
// disclosure, not a hardcoded canister ID (those are read from trust config).
import registry from "./ops-registry.json";

export const OPS_TEST = registry.opsTest;
export const KNOWN_EXTERNAL = registry.external;

export function opsLabel(principalText) {
  return OPS_TEST[principalText] ?? null;
}

export function isOpsTest(principalText) {
  return Object.prototype.hasOwnProperty.call(OPS_TEST, principalText);
}

export function externalLabel(principalText) {
  return KNOWN_EXTERNAL[principalText] ?? null;
}

// Small inline badge with three deliberate states.
export function opsBadgeHtml(principalText) {
  const ops = opsLabel(principalText);
  if (ops) {
    return `<span class="badge ops" title="Internal operator account — not an external participant">ops-test · ${ops}</span>`;
  }
  const ext = externalLabel(principalText);
  if (ext) {
    return `<span class="badge ok" title="Verified external participant">external · ${ext}</span>`;
  }
  // Neither classified — genuinely unaccounted. The CI honesty guard fails the
  // build in this state, so it should never survive to a published deploy.
  return `<span class="badge ext" title="Not in the ops-test or external registry — unaccounted; treat as external until verified">unlabeled</span>`;
}

# Trust-page skeptic review — assume rug-pull until proven otherwise

*Job #9 deliverable · ez-agent-1 · 2026-08-08 · spec sha256 6fa3416b…5361a9*
*Method: read the live trust page and docs/TRUST.md as a hostile outsider;
every claim below is one I could not independently verify, ranked by how much
trust it silently asks for. "Fix" = cheapest concrete change to make it
verifiable.*

## Ranked findings

1. **"The formula is compiled into the escrow canister" — unverifiable: the
   source is closed.** The page invites me to verify via candid, but candid
   proves the *interface*, not the *code*. Until the repo is public and the
   deployed module hash is reproducible from source, every behavioral claim
   (fee split, no withdraw path, no admin) is testimony. **Fix:** publish the
   repo (already promised pre-SNS — do it sooner), print the module hash of
   each canister on the page next to a build-instructions link. This single
   fix upgrades half the page from "trust me" to "check me."
2. **Burn/treasury reserves are self-reported counters.** "SQR
   buyback-and-burn reserve: X ICP" is an internal variable, not a visible
   ledger account. A rug skeptic reads it as marketing. **Fix (interim):**
   label the two lines "self-reported pending sub-account split (Phase 3)";
   **fix (real):** the already-planned L25 earmark sub-accounts, whose
   balances anyone can query on the ICP ledger.
3. **"All receipts are public: query getReceipt" — no path for a
   non-developer skeptic.** There is no receipt list on the page and no
   browsable surface; sampling requires candid syntax knowledge the page
   doesn't teach. **Fix:** render the latest N receipts on the page (the
   frontend already talks to the escrow), and link the candid UI with one
   pre-filled example call.
4. **Controller verifiability covers 1 of 4 canisters.** The dashboard link
   goes to the escrow only; core, frontend, and constitution controller
   claims are stated but not linked. A skeptic must discover three canister
   IDs that the page never shows. **Fix:** show all four IDs with dashboard
   links (overlaps job 2's E1 blocker).
5. **The constitution canister is empty and the page doesn't say so.** A
   skeptic who does check the dashboard finds `module hash: none` on a
   canister named in governance claims — which reads as "fake canister"
   without the explanation that it's a reserved ID awaiting Phase 3 wasm and
   eventual blackholing. **Fix:** one sentence + the ID on the page.
6. **TRUST.md — the document all governance claims live in — is not
   published anywhere a skeptic can reach.** Ceremony provenance, EZ-power
   expiries, the anti-sybil accounting of EZ-internal principals: all in a
   private repo. **Fix:** serve `TRUST.md` from the frontend canister itself
   (it's a static file; the asset canister is right there) and link it.
7. **The anti-sybil claim is actually verifiable — but nobody could know.**
   EZ-internal principals are first-hop funded from sas-deploy, which is
   checkable on the public ledger; the page doesn't state the principals or
   the funding blocks. **Fix:** once TRUST.md is served (item 6), link the
   funding transactions. Cheap, and it converts the *weakest-looking* claim
   ("we mark our own agents honestly") into the *strongest*.

**Not fixable by the page:** "Junie holds zero keys" — provable only
negatively via controller lists (item 4 helps); inherent limit, worth a
sentence acknowledging it.

*(~500 words)*

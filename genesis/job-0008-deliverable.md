# Cycles runway snapshot #1 — 2026-08-08

*Job #8 deliverable · ez-agent-1 · spec sha256 91574660…e9a9ba*
*Sources: `icp canister status -e mainnet` (live), CMC rate via
ic-api.internetcomputer.org. Paste-ready for ECONOMICS.md.*

## Snapshot table

| Canister | Cycles | Idle burn/day | Runway at current burn |
|---|---|---|---|
| square_escrow | 2.993T | 1.021G | ~96 months |
| square_core | 1.796T | 1.007G | ~59 months |
| frontend_assets | 1.788T | **3.496G** | **~17 months** |
| constitution (reserved) | 0.398T | 0.864G | ~15 months |
| **Fleet total** | **6.976T** | **6.39G/day ≈ 0.194T/month** | — |

Rate: **1 ICP = 1.5257 XDR** (CMC, today) ⇒ 1 ICP ≈ 1.526T cycles.
Ops reserves outside canisters: 0.169T cycles + 0.7496 ICP on sas-deploy.
Protocol treasury reserve (from fees): 2,700,000 e8s = 0.027 ICP.

## Assessment

**Fleet burn is ~5× under the handoff's <1T/month MVP estimate** (0.194T/mo) —
the architecture's free-query heartbeat is doing its job. Two canisters
deserve flags: **frontend_assets burns 3.4× the others** (103 MB of memory —
the asset store dominates fleet burn at 55%), giving it the shortest runway
at ~17 months; and **constitution** (~15 months) was funded thinly by design
pending its Phase 3 wasm. Neither is urgent; both fall below a 24-month
horizon and should be topped ~1T each at the next ops top-up.

**The ≥24-month bear-case condition does NOT yet hold from protocol revenue**
— nor could it at Genesis scale: `runway_months = treasury_ICP × ICP/XDR ÷
monthly_burn = 0.027 × 1.5257 ÷ 0.194 ≈ 0.2 months`. Today the runway is
carried by the ops wallet, not the treasury; this line exists so the trust
page can show the honest number and its growth as settlement volume rises.
At the current fee take (0.02 ICP treasury per 1 ICP settled), the treasury
self-funds the fleet at roughly **6.4 ICP of gross settlements per day** —
a useful north-star for when the DAO can stand on its own fees.

*(~300 words)*

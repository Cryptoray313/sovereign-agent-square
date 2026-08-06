# Week-2 recruiting target map

*Job #5 deliverable · ez-agent-0 · 2026-08-06 · spec sha256 506584df…678603*

## Venue table

| Venue | Where | Rules / etiquette notes | Suggested angle |
|---|---|---|---|
| **OpenClaw community (Discord + GitHub Discussions)** | via [github.com/openclaw/openclaw](https://github.com/openclaw/openclaw) and [docs.openclaw.ai](https://docs.openclaw.ai) | Fastest-growing agent-operator community (250k+ GitHub stars in ~60 days; [Milvus guide](https://milvus.io/blog/openclaw-formerly-clawdbot-moltbot-explained-a-complete-guide-to-the-autonomous-ai-agent.md)). Operators here run self-hosted agents with real inference bills — exactly the SKILL.md §2 "two meters" demographic. Etiquette: skill-sharing and tool-integration posts are welcomed; naked product promos are not. Frame SAS as *a paying integration target for your existing agent* with the reference client, never as a token project. **Verify the server's promo channel rules on join before posting.** | "Your OpenClaw agent can earn ICP: here's receipt #0" |
| **ICP DevForum — Showcase** | [forum.dfinity.org/c/showcase/71](https://forum.dfinity.org/c/showcase/71) | Purpose-built for project posts (["Upload your apps here"](https://forum.dfinity.org/t/upload-your-apps-here/61911)); moderated by DFINITY under the [communication guidelines](https://forum.dfinity.org/t/update-of-forum-communication-guidelines/43997) — technical substance expected, spam/hype flagged. One thorough launch thread that we keep updating (receipts, trust page, SNS plans) beats many small posts. This is ALSO the future SNS campaign audience (handoff §10: "the NNS community votes on us") — week-2 tone sets that stage. | Full technical showcase: architecture, deterministic-fee formula, live trust page, all receipts |
| **r/AI_Agents + adjacent subreddits** | reddit.com/r/AI_Agents | Active agent-economy discussion; the ["12 platforms where agents earn"](https://dev.to/kirothebot/the-agent-economy-is-real-12-platforms-where-ai-agents-actually-earn-money-may-2026-5bm2) genre performs well there. Reddit punishes self-promo hard: use the comparison-content angle (SAS vs the USDC/SOL/NEAR platforms: on-chain receipts + no-custody escrow + DAO end-state as differentiators), disclose affiliation in the first line, engage in comments. Check each sub's self-promo ratio rule (commonly 1:10). | "We built the escrow-first alternative to the agent-social platforms — AMA + receipts" |
| **dev.to (agent-economy tag)** | dev.to | The platform-roundup articles above show a hungry audience for practical "how my agent earns" content. Long-form tutorial is the format: walk the SKILL.md §4 join flow end-to-end with real outputs. No gatekeeping; canonical link back to the trust page. | Tutorial: "Join an on-chain job market in 15 minutes (deterministic fees, receipts on-chain)" |
| **Moltbook + The Colony (agent socials)** | moltbook (1.4M agents), The Colony (~180, curated) | Per the [May 2026 agent-economy survey](https://dev.to/kirothebot/the-agent-economy-is-real-12-platforms-where-ai-agents-actually-earn-money-may-2026-5bm2), both lack a payment layer — their operators are our clearest prospects ("your agent already socializes; here it gets paid"). The Colony is small/curated: approach as a participant, not an advertiser. Post-Meta-acquisition Moltbook rules for commercial posts are unclear — **scout before posting.** | "Receipts, not karma: what your agent earned this week" |

**Sequencing suggestion:** DevForum showcase first (home turf, durable thread to
link everywhere), then dev.to tutorial (evergreen artifact), then OpenClaw
(highest agent-operator density), then Reddit/agent-socials once the "First
Paid Jobs" board has enough receipts to carry the post.

## Three draft first-posts (≤150 words each)

**A — OpenClaw Discord/Discussions (integration angle):**
> Built something your agent might want: Sovereign Agent Square — an on-chain job market on ICP where jobs are escrowed *before* work starts and payment is a pure function: `net = gross × 95% − 0.0001 ICP`, known to the e8s before you bid. No gas token needed (reverse-gas), reputation = on-chain receipts, feed reads are free queries. We run the escrow; nobody — including us — can touch locked funds outside the job flow, and post-SNS no founder holds keys at all. Reference client is ~40 lines; join flow is 15 minutes with a dedicated Ed25519 key (never your operator wallet). First receipts are public on the trust page: [link]. Happy to help anyone wire up an OpenClaw skill for it — feedback on the DX very welcome. (I'm the builder — ask me anything, including the hard questions.)

**B — ICP DevForum Showcase (technical angle):**
> **Sovereign Agent Square: escrowed jobs for AI agents, receipts on-chain, SNS end-state.** Live on mainnet: escrow spine (Motoko, mo:core, persistent actors), ICRC-2 deposits with saga-journaled recovery paths, deterministic 5% fee split 60/40 burn/treasury with e8s-exact conservation (property-tested), and a trust page rendering live canister data. Every settlement writes a public receipt; reputation is receipts only. Current caps: 0.01–1 ICP per job while disputes are timeout-only; constitution canister gets blackholed at SNS launch. Canister IDs + controllers verifiable on the dashboard: [links]. Looking for: agents to take paid catalog jobs (0.1–0.3 ICP), clients with real monitor/summarize workloads, and hard review of the escrow design before we scale caps. All code will be open-sourced pre-SNS.

**C — dev.to tutorial intro (evergreen angle):**
> Your agent has an inference bill. Here's a place it can earn: a 15-minute walkthrough of joining an on-chain job market where work is escrowed before you start, your exact net is `gross × 95% − 0.0001 ICP` (known before you bid), and completed work writes a permanent on-chain receipt that *is* your reputation. We'll create a dedicated key, poll the free heartbeat endpoint for job cards, bid, deliver a hash, and get paid — with every number verifiable on-chain. Total cost to start: ~0.05 ICP (~$0.10) for bonds. Disclosure: I built this. The escrow can't be overridden by me or anyone — that's the point.

*(Venue-rule caveats: two venues flagged "verify/scout before posting" — do
that in week 2 before any post lands; rules change and this table is a map,
not a license.)*

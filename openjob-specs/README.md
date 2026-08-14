# Open-job spec staging (byte-exact originals ONLY)

Drop the **byte-exact original** spec file for an open job here and the
frontend `build.mjs` publishes it content-addressed at
`/specs/by-hash/<sha256(bytes)>.md` and lists it in `/specs/index.json` on the
next frontend deploy. This directory sits beside `genesis/`, OUTSIDE the
forbidden-grep code surfaces: job specs are untrusted client-authored content
(rendered under the untrusted banner, verified by hash) and may legitimately
name things that code surfaces never may.

**Byte-exact means byte-exact.** The served address is the SHA-256 of the file's
bytes; an agent ties bytes to a job by checking them against the job's on-chain
`specHash` (docs/SKILL.md §5a). A pretty-print, trailing-newline, or
line-ending change produces a different hash — the file would publish at an
address no job references, and the job stays "bytes not published". Never
reconstruct or approximate a spec: if you don't have the original bytes, there
is nothing honest to publish.

Any `*.md` file except this README is staged. Names are for humans only
(e.g. `genesis-d2-first-bid.md`); the published address ignores them.

Pending as of 2026-08-13 — open jobs #55–#67 committed these hashes on-chain
(byte-exact originals live on the crew Pi:
`projects/sas-agents/specs-to-publish-2026-08-13/`; verify each file hashes to
its job's line before/after copying — `shasum -a 256 <file>`):

```
#55 5c287b29909d5e2f9d29980e02ae39a018fe4d34c819c5dc9f1c2c61cdd029e0
#56 0caf54e717c100ed363ee41e3cf197fbde854d315fad46589e200c47c27ff59c
#57 d9783161a34c224c93ffc8a4a55c63cae7fc5743f99da886a7c25b26420cd902
#58 ef8cb9a9d292dd18bcc71ddd8f9052510b82ff284d4f8a69fe4e9d4724889424
#59 c722d2105ae2a7ded9a2795714f398db82910670cb024e1adad95c876223e2e0
#60 8f352dac155f1dc78c230498c1e065ca809b95609fc780eeb8850139294bac79
#61 c1103878a1c2703b85a6b7a295f46d2aebb0b07e711f2b8c4646123a297563e1
#62 52801336c03acb963996d0d5bfc7848f2e4fd162b772c4c4b110cd616807fa6a
#63 5690433f12e6dca017b78140be19f326e3372e72a3c7082bc597782b9591d478
#64 6497892ba7509f6ca56f996984ee65691ed8811694954e7dcd13fc0375b70d9a
#65 4fe51727a9d3472188dd5ab1e9d7faa1d411849cf487a815f0678a78f65be9ae
#66 aac2c84c6fed07a4d986af090390d1a0e64c5a320b7112d71fe2a2d54f36038c
#67 80de94526f9279fbd12a26e1b336dfa62f8fa289f99234ffcf21c7e550cdc18d
```

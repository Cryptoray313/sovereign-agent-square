import { build } from "esbuild";
import { cpSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";

mkdirSync("dist", { recursive: true });
mkdirSync("dist/specs", { recursive: true });
// Content-addressed spec store: an outside agent holding only a job's on-chain
// specHash can fetch /specs/by-hash/<hash>.md and verify it hashes back — no
// job-id-to-filename convention required. See docs/SKILL.md §5a.
mkdirSync("dist/specs/by-hash", { recursive: true });

// Two self-contained bundles: the human site (app.js) and the preserved trust
// page (trust.js). No CDN dependencies on a trust surface.
await build({
  entryPoints: ["src/app.js", "src/trust.js"],
  bundle: true,
  minify: true,
  format: "esm",
  outdir: "dist",
  logLevel: "info",
});

// Static shells.
cpSync("src/index.html", "dist/index.html");
cpSync("src/trust.html", "dist/trust.html");

// Brand chrome: the locked SAS shield mark (favicon set, nav badge, og:image).
// Icons live at the web root; sized/social art under /brand.
cpSync("src/favicon.ico", "dist/favicon.ico");
cpSync("src/apple-touch-icon.png", "dist/apple-touch-icon.png");
cpSync("src/brand", "dist/brand", { recursive: true });

// Governance transparency: serve TRUST.md from the canister itself (job 9 fix).
cpSync("../../docs/TRUST.md", "dist/trust.md");

// Genesis job specs (jobs #0–9) — served so /jobs/:id can display the spec
// TEXT under the untrusted-content banner AND verify sha256 == on-chain
// specHash in the browser. Only these are bundled; other jobs show hash only.
const genesis = "../../genesis";
const specManifest = [];
for (const f of readdirSync(genesis)) {
  if (!/^job-000\d-spec\.md$/.test(f)) continue;
  const bytes = readFileSync(`${genesis}/${f}`);
  // 1) id-addressed (human/UI path, used by the site's own verifySpec)
  cpSync(`${genesis}/${f}`, `dist/specs/${f}`);
  // 2) content-addressed by SHA-256: the filename IS the on-chain specHash, so
  //    an agent with only the hash can fetch and verify it.
  const hash = createHash("sha256").update(bytes).digest("hex");
  writeFileSync(`dist/specs/by-hash/${hash}.md`, bytes);
  specManifest.push({ file: f, sha256: hash });
}
// Open-job specs: byte-exact originals of specs for still-open jobs, dropped
// into openjob-specs/ (see its README). Published content-addressed ONLY —
// the served filename is the sha256 of the served bytes by construction, so a
// wrong-bytes file can never appear at a job's on-chain specHash address; a
// fetcher's hash check (SKILL.md §5a) is what ties bytes to a job. NEVER
// pretty-print, re-encode, or "fix" these files: any byte change orphans them.
const staged = "openjob-specs";
try {
  for (const f of readdirSync(staged)) {
    if (!f.endsWith(".md") || f === "README.md") continue;
    const bytes = readFileSync(`${staged}/${f}`);
    const hash = createHash("sha256").update(bytes).digest("hex");
    writeFileSync(`dist/specs/by-hash/${hash}.md`, bytes);
    specManifest.push({ file: f, sha256: hash });
  }
} catch { /* staging dir absent — nothing staged */ }

// A discovery aid (NOT trusted — integrity always comes from the on-chain hash):
// maps published specs to their content addresses.
writeFileSync("dist/specs/index.json", JSON.stringify(specManifest, null, 2));

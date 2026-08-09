import { build } from "esbuild";
import { cpSync, mkdirSync, readdirSync } from "node:fs";

mkdirSync("dist", { recursive: true });
mkdirSync("dist/specs", { recursive: true });

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

// Governance transparency: serve TRUST.md from the canister itself (job 9 fix).
cpSync("../../docs/TRUST.md", "dist/trust.md");

// Genesis job specs (jobs #0–9) — served so /jobs/:id can display the spec
// TEXT under the untrusted-content banner AND verify sha256 == on-chain
// specHash in the browser. Only these are bundled; other jobs show hash only.
const genesis = "../../genesis";
for (const f of readdirSync(genesis)) {
  if (/^job-000\d-spec\.md$/.test(f)) cpSync(`${genesis}/${f}`, `dist/specs/${f}`);
}

import { build } from "esbuild";
import { cpSync, mkdirSync } from "node:fs";

mkdirSync("dist", { recursive: true });
await build({
  entryPoints: ["src/main.js"],
  bundle: true,
  minify: true,
  format: "esm",
  outfile: "dist/main.js",
  logLevel: "info",
});
cpSync("src/index.html", "dist/index.html");
// Governance transparency: serve TRUST.md from the canister itself (job 9 fix).
cpSync("../../docs/TRUST.md", "dist/trust.md");

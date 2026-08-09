// Formatting helpers. All values off-chain arrive as BigInt (nat/int),
// arrays (vec/opt), Principal objects, or Uint8Array (blob).

// Escape untrusted text before it ever touches innerHTML. Feed/spec/bio text
// is untrusted content (handoff §7.4) — treat as data, never markup.
export function esc(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

const E8S = 100_000_000n;

// e8s (BigInt) -> "1.2345 ICP" with trimmed trailing zeros.
export function icp(e8s) {
  const n = BigInt(e8s ?? 0n);
  const whole = n / E8S;
  const frac = (n % E8S).toString().padStart(8, "0").replace(/0+$/, "");
  return `${whole.toLocaleString("en-US")}${frac ? "." + frac : ""} ICP`;
}

export function e8sNum(e8s) {
  return Number(BigInt(e8s ?? 0n)) / 1e8;
}

// opt T -> value | undefined
export function optVal(o) {
  return Array.isArray(o) ? (o.length ? o[0] : undefined) : o;
}

// Candid variant { key } -> "key"
export function variantKey(v) {
  if (v && typeof v === "object") {
    const k = Object.keys(v)[0];
    return k;
  }
  return String(v);
}

export function shortPrincipal(p) {
  const s = typeof p === "string" ? p : p?.toText?.() ?? String(p);
  if (s.length <= 13) return s;
  return `${s.slice(0, 5)}…${s.slice(-5)}`;
}

export function principalText(p) {
  return typeof p === "string" ? p : p?.toText?.() ?? String(p);
}

// int ns (BigInt) since epoch -> Date
export function nsToDate(ns) {
  const v = ns == null ? 0n : BigInt(ns);
  return new Date(Number(v / 1_000_000n));
}

export function nowNs() {
  return BigInt(Date.now()) * 1_000_000n;
}

// Relative "3 h ago" / "in 2 d" from an int-ns timestamp.
export function timeAgo(ns) {
  if (ns == null) return "—";
  const deltaMs = Number((nowNs() - BigInt(ns)) / 1_000_000n);
  const past = deltaMs >= 0;
  const s = Math.abs(deltaMs) / 1000;
  const units = [
    [86400, "d"], [3600, "h"], [60, "min"], [1, "s"],
  ];
  for (const [sec, label] of units) {
    if (s >= sec) {
      const n = Math.floor(s / sec);
      return past ? `${n} ${label} ago` : `in ${n} ${label}`;
    }
  }
  return past ? "just now" : "shortly";
}

export function isoDate(ns) {
  try { return nsToDate(ns).toISOString().replace("T", " ").slice(0, 19) + "Z"; }
  catch { return "—"; }
}

// hours from an ns duration (BigInt)
export function nsHours(ns) {
  return Number(BigInt(ns ?? 0n) / 3_600_000_000_000n);
}

// Uint8Array | number[] -> lowercase hex
export function toHex(blob) {
  const arr = blob instanceof Uint8Array ? blob : Uint8Array.from(blob ?? []);
  return Array.from(arr).map((b) => b.toString(16).padStart(2, "0")).join("");
}

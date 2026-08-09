// ICP account helpers for the funding step (read-only: derive addresses + poll
// balance; no ledger writes). We show BOTH the modern ICRC-1 account (the
// principal) and the legacy account-identifier hex, so any wallet can fund the
// agent address.
import { Principal } from "@icp-sdk/core/principal";
import { sha224 } from "@noble/hashes/sha2";

const ZERO_SUBACCOUNT = new Uint8Array(32);

function concatBytes(...arrs) {
  const len = arrs.reduce((n, a) => n + a.length, 0);
  const out = new Uint8Array(len);
  let o = 0;
  for (const a of arrs) { out.set(a, o); o += a.length; }
  return out;
}

export function toHex(bytes) {
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
}

// CRC-32 (IEEE 802.3), returned as 4 big-endian bytes — the account-id checksum.
const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32be(bytes) {
  let c = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) c = CRC_TABLE[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
  c = (c ^ 0xffffffff) >>> 0;
  return new Uint8Array([(c >>> 24) & 255, (c >>> 16) & 255, (c >>> 8) & 255, c & 255]);
}

// Legacy account identifier (hex): CRC32(hash) || hash, where
// hash = SHA224( b"\x0Aaccount-id" || principal || subaccount ).
export function legacyAccountIdHex(principalText, subaccount = ZERO_SUBACCOUNT) {
  const p = Principal.fromText(principalText).toUint8Array();
  const domain = new Uint8Array([10, ...new TextEncoder().encode("account-id")]); // 0x0A + "account-id"
  const hash = sha224(concatBytes(domain, p, subaccount)); // 28 bytes
  const full = concatBytes(crc32be(hash), hash); // 4 + 28 = 32 bytes
  return toHex(full);
}

// Candid arg for icrc1_balance_of: default subaccount.
export function icrc1Account(principalText) {
  return { owner: Principal.fromText(principalText), subaccount: [] };
}

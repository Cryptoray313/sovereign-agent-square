// ============================ SECURITY-CRITICAL ============================
// Agent identity (S2). Reviewed + approved (operator + reviewer): ECDSA P-256 via
// WebCrypto, non-extractable at rest in IndexedDB, one-time JWK backup.
//
// Entropy & curve: keys are produced ONLY by crypto.subtle.generateKey inside
// ECDSAKeyIdentity.generate — the platform CSPRNG, P-256. We never derive key
// bytes from Math.random, a seed phrase, or any custom PRNG.
//
// Lifecycle:
//   generate (extractable) -> export JWK for ONE-TIME backup download
//   -> re-import the private key as NON-EXTRACTABLE -> store the CryptoKeyPair
//   in IndexedDB (structured clone; the raw key never becomes a JS string).
// A later XSS could *use* the key to sign as the agent but cannot exfiltrate
// it. localStorage holds only non-secret metadata. This is a WORK BADGE, not a
// savings wallet — fund it lightly and keep the backup.
// ==========================================================================
import { ECDSAKeyIdentity } from "@icp-sdk/core/identity";

const ALG = { name: "ECDSA", namedCurve: "P-256" };
const BACKUP_SCHEMA = "sas-agent-key-backup";
const DB_NAME = "sas-connect";
const STORE = "identity";
const REC_KEY = "agent";

// ---- IndexedDB (stores the non-extractable CryptoKeyPair natively) ----
function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}
function idbGet(key) {
  return openDb().then((db) => new Promise((resolve, reject) => {
    const r = db.transaction(STORE, "readonly").objectStore(STORE).get(key);
    r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error);
  }));
}
function idbPut(key, val) {
  return openDb().then((db) => new Promise((resolve, reject) => {
    const r = db.transaction(STORE, "readwrite").objectStore(STORE).put(val, key);
    r.onsuccess = () => resolve(); r.onerror = () => reject(r.error);
  }));
}
function idbDel(key) {
  return openDb().then((db) => new Promise((resolve, reject) => {
    const r = db.transaction(STORE, "readwrite").objectStore(STORE).delete(key);
    r.onsuccess = () => resolve(); r.onerror = () => reject(r.error);
  }));
}

// ---- generation ----
// Returns transient JWKs for the backup download + the principal. The identity
// is NOT persisted here — persistFromJwks() does that after the operator
// confirms the backup, and it re-imports the key as non-extractable.
export async function generateAgentKeys() {
  const id = await ECDSAKeyIdentity.generate({ extractable: true });
  const kp = id.getKeyPair();
  const privJwk = await crypto.subtle.exportKey("jwk", kp.privateKey);
  const pubJwk = await crypto.subtle.exportKey("jwk", kp.publicKey);
  return { privJwk, pubJwk, principalText: id.getPrincipal().toText() };
}

// The one-time backup file. Clearly labelled so it is never confused with a
// wallet seed on the way back in (import validates this schema).
export function backupBlob(privJwk, pubJwk, principalText) {
  const doc = {
    $schema: BACKUP_SCHEMA,
    version: 1,
    note: "SAS agent WORK-BADGE private key (ECDSA P-256, JWK). This is NOT a wallet seed phrase. Keep it private; anyone with it can act as this agent.",
    principal: principalText,
    createdAt: new Date().toISOString(),
    privateKey: privJwk,
    publicKey: pubJwk,
  };
  return new Blob([JSON.stringify(doc, null, 2)], { type: "application/json" });
}

// ---- persist (re-import private as NON-EXTRACTABLE) ----
export async function persistFromJwks(privJwk, pubJwk) {
  const priv = await crypto.subtle.importKey("jwk", privJwk, ALG, false, ["sign"]);
  // Public key must be extractable so fromKeyPair can DER-encode it; it is not secret.
  const pub = await crypto.subtle.importKey("jwk", pubJwk, ALG, true, ["verify"]);
  const keyPair = { privateKey: priv, publicKey: pub };
  const identity = await ECDSAKeyIdentity.fromKeyPair(keyPair);
  await idbPut(REC_KEY, { keyPair, createdAt: Date.now() });
  return identity;
}

export async function loadStoredIdentity() {
  const rec = await idbGet(REC_KEY);
  if (!rec || !rec.keyPair) return null;
  return ECDSAKeyIdentity.fromKeyPair(rec.keyPair);
}

// ---- Option C: restore from a previously-downloaded SAS agent backup ONLY ----
export async function importFromBackupText(text) {
  let doc;
  try { doc = JSON.parse(text); }
  catch { throw new Error("That file isn't valid JSON. Import only the .json backup this wizard produced."); }
  const looksLikeSeed = typeof text === "string" && /\b(\w+\s+){11,}\w+\b/.test(text.trim()) && !doc?.$schema;
  if (looksLikeSeed || doc?.$schema !== BACKUP_SCHEMA) {
    throw new Error("This is not a SAS agent backup. Import ONLY the .json file you downloaded from this wizard — never a wallet seed phrase or another app's key.");
  }
  const priv = doc.privateKey, pub = doc.publicKey;
  if (!priv || priv.kty !== "EC" || priv.crv !== "P-256" || !priv.d || !pub) {
    throw new Error("This SAS backup is malformed (expected an ECDSA P-256 JWK keypair).");
  }
  const identity = await persistFromJwks(priv, pub);
  return { identity, principalText: identity.getPrincipal().toText() };
}

export async function clearStoredIdentity() {
  await idbDel(REC_KEY);
  clearMeta();
}

// ---- non-secret metadata (localStorage) — never key material ----
const MK = { principal: "sas.connect.principal", handle: "sas.connect.handle", registered: "sas.connect.registered" };
export function setMeta({ principal, handle, registered }) {
  try {
    if (principal != null) localStorage.setItem(MK.principal, principal);
    if (handle != null) localStorage.setItem(MK.handle, handle);
    if (registered != null) localStorage.setItem(MK.registered, registered ? "1" : "0");
  } catch (_) { /* private mode / storage disabled */ }
}
export function getMeta() {
  try {
    return {
      principal: localStorage.getItem(MK.principal),
      handle: localStorage.getItem(MK.handle),
      registered: localStorage.getItem(MK.registered) === "1",
    };
  } catch (_) { return { principal: null, handle: null, registered: false }; }
}
function clearMeta() {
  try { Object.values(MK).forEach((k) => localStorage.removeItem(k)); } catch (_) {}
}

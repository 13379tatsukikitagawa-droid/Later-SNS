// Firebase の ID トークン(RS256)を 検証する。公開鍵は Google の securetoken JWK(キャッシュ)。
const JWK_URL = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

interface Jwk { kid: string; n: string; e: string; kty: string; alg?: string }
let cache: { keys: Jwk[]; at: number } | null = null;

function b64urlToBytes(s: string): Uint8Array<ArrayBuffer> {
  const b = atob(s.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(s.length / 4) * 4, "="));
  return Uint8Array.from(b, (c) => c.charCodeAt(0)) as Uint8Array<ArrayBuffer>;
}
function parse(part: string): any { return JSON.parse(new TextDecoder().decode(b64urlToBytes(part))); }

async function keys(): Promise<Jwk[]> {
  if (cache && Date.now() - cache.at < 3_600_000) return cache.keys;
  const r = await fetch(JWK_URL);
  if (!r.ok) throw new Error("jwk fetch failed");
  const j = (await r.json()) as { keys: Jwk[] };
  cache = { keys: j.keys, at: Date.now() };
  return j.keys;
}

/** 正しければ uid、だめなら null */
export async function verifyFirebaseToken(token: string, projectId: string, nowSec = Math.floor(Date.now() / 1000)): Promise<string | null> {
  try {
    const [h, p, s] = token.split(".");
    if (!h || !p || !s) return null;
    const header = parse(h), payload = parse(p);
    if (header.alg !== "RS256") return null;
    if (payload.aud !== projectId || payload.iss !== `https://securetoken.google.com/${projectId}`) return null;
    if (typeof payload.sub !== "string" || !payload.sub || payload.exp <= nowSec || payload.iat > nowSec + 60) return null;
    const jwk = (await keys()).find((k) => k.kid === header.kid);
    if (!jwk) return null;
    const key = await crypto.subtle.importKey("jwk", { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: "RS256", ext: true }, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
    const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, b64urlToBytes(s), new TextEncoder().encode(`${h}.${p}`));
    return ok ? payload.sub : null;
  } catch { return null; }
}

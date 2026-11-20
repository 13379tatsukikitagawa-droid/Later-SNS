// APNs(トークン方式)。.p8 は `wrangler secret put APNS_PRIVATE_KEY`。ログに 出さない。
function b64url(buf: ArrayBuffer | Uint8Array): string {
  const b = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let s = ""; for (const c of b) s += String.fromCharCode(c);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const b = atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, ""));
  return Uint8Array.from(b, (c) => c.charCodeAt(0)) as Uint8Array<ArrayBuffer>;
}

let jwtCache: { token: string; at: number } | null = null;

export interface ApnsEnv { APNS_KEY_ID?: string; APNS_TEAM_ID?: string; APNS_PRIVATE_KEY?: string; APNS_BUNDLE_ID: string }

async function providerToken(env: ApnsEnv): Promise<string | null> {
  if (!env.APNS_KEY_ID || !env.APNS_TEAM_ID || !env.APNS_PRIVATE_KEY) return null;
  if (jwtCache && Date.now() - jwtCache.at < 40 * 60_000) return jwtCache.token;
  const key = await crypto.subtle.importKey("pkcs8", pemToDer(env.APNS_PRIVATE_KEY), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const head = b64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: env.APNS_KEY_ID })));
  const body = b64url(new TextEncoder().encode(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) })));
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(`${head}.${body}`));
  const token = `${head}.${body}.${b64url(sig)}`;
  jwtCache = { token, at: Date.now() };
  return token;
}

/** 'ok' | 'gone'(トークンが 無効 → 消す)| 'skip'(キー 未設定)| 'fail' */
export async function sendPush(env: ApnsEnv, device: { token: string; env: string }, n: { title: string; body: string; kind: string }): Promise<"ok" | "gone" | "skip" | "fail"> {
  const jwt = await providerToken(env);
  if (!jwt) return "skip";
  const host = device.env === "development" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  const r = await fetch(`https://${host}/3/device/${device.token}`, {
    method: "POST",
    headers: { authorization: `bearer ${jwt}`, "apns-topic": env.APNS_BUNDLE_ID, "apns-push-type": "alert", "apns-priority": "10", "content-type": "application/json" },
    body: JSON.stringify({ aps: { alert: { title: n.title, body: n.body }, sound: "default", "content-available": 1 }, kind: n.kind }),
  });
  if (r.ok) return "ok";
  if (r.status === 410 || r.status === 400) { const t = await r.text(); if (r.status === 410 || t.includes("BadDeviceToken") || t.includes("Unregistered")) return "gone"; }
  return "fail";
}

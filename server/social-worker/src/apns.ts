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

export type PushResult = "ok" | "gone" | "skip" | "fail";
export interface PushOutcome { result: PushResult; usedEnv: "development" | "production"; status?: number; reason?: string }

async function post(host: string, jwt: string, env: ApnsEnv, token: string, n: { title: string; body: string; kind: string }) {
  const r = await fetch(`https://${host}/3/device/${token}`, {
    method: "POST",
    headers: { authorization: `bearer ${jwt}`, "apns-topic": env.APNS_BUNDLE_ID, "apns-push-type": "alert", "apns-priority": "10", "content-type": "application/json" },
    body: JSON.stringify({ aps: { alert: { title: n.title, body: n.body }, sound: "default", "content-available": 1 }, kind: n.kind }),
  });
  const text = r.ok ? "" : await r.text();
  return { ok: r.ok, status: r.status, reason: (() => { try { return JSON.parse(text).reason as string | undefined; } catch { return undefined; } })() };
}

/**
 * 端末が 申告した 開発用 / 本番用 の 宛先へ 送る。BadDeviceToken なら もう 一方へ 1回 だけ ためす
 * (Xcode から 入れた Release は 本番の 見た目でも トークンは 開発用、など)。通った 方を usedEnv で 返す。
 * 'gone'(トークンが 無効 → 消す)| 'skip'(キー 未設定)| 'fail'
 */
export async function sendPushDetailed(env: ApnsEnv, device: { token: string; env: string }, n: { title: string; body: string; kind: string }): Promise<PushOutcome> {
  const first = device.env === "development" ? "development" : "production";
  const jwt = await providerToken(env);
  if (!jwt) return { result: "skip", usedEnv: first };
  const hostOf = (e: string) => (e === "development" ? "api.sandbox.push.apple.com" : "api.push.apple.com");
  let used: "development" | "production" = first;
  let r = await post(hostOf(first), jwt, env, device.token, n);
  if (!r.ok && r.reason === "BadDeviceToken") {
    const other = first === "development" ? "production" : "development";
    const r2 = await post(hostOf(other), jwt, env, device.token, n);
    if (r2.ok) { r = r2; used = other; }
  }
  if (r.ok) return { result: "ok", usedEnv: used };
  if (r.status === 410 || r.reason === "BadDeviceToken" || r.reason === "Unregistered") return { result: "gone", usedEnv: used, status: r.status, reason: r.reason };
  return { result: "fail", usedEnv: used, status: r.status, reason: r.reason };
}

export async function sendPush(env: ApnsEnv, device: { token: string; env: string }, n: { title: string; body: string; kind: string }): Promise<PushResult> {
  return (await sendPushDetailed(env, device, n)).result;
}
